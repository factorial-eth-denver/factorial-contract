import {ethers} from 'hardhat';
import {
    DebtNFT,
    ERC20Asset,
    MockERC20,
    OracleRouter,
    SyntheticFT,
    SyntheticNFT,
    TestHelper,
    Tokenization,
    FactorialRouter, MockTriggerHandler, ITriggerLogic, Margin,
    SimpleBorrower, Lending, Trigger, Liquidation, LiquidationBasic, LiquidationAuction, TriggerLogicStopLoss, TriggerLogicTakeProfit, TriggerLogicMaturity, AssetManagement
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture from "./fixture/factorialFixture3";
import {expect} from "chai";
import { BigNumber } from 'ethers';
import {
    DEBT_NFT_TOKEN_TYPE,
    SYNTHETIC_NFT_TOKEN_TYPE
} from "./shared/constants";

const MAX = BigNumber.from(2).pow(250).sub(1);
const NO_ADDRESS = "0x0000000000000000000000000000000000000000";

describe('Margin unit test', () => {
    let weth: MockERC20
    let usdc: MockERC20
    let asset: AssetManagement
    let router: FactorialRouter
    let oracleRouter: OracleRouter
    let tokenization: Tokenization
    let debtNFT: DebtNFT
    let erc20Asset: ERC20Asset
    let syntheticFT: SyntheticFT
    let syntheticNFT: SyntheticNFT
    let helper: TestHelper
    let simpleBorrower: SimpleBorrower
    let lending: Lending
    let trigger: Trigger
    let liquidation: Liquidation
    let liquidationBasic: LiquidationBasic
    let liquidationAuction: LiquidationAuction
    let triggerLogicStopLoss: TriggerLogicStopLoss
    let triggerLogicTakeProfit: TriggerLogicTakeProfit
    let triggerLogicMaturity: TriggerLogicMaturity
    let mockTriggerHandler: MockTriggerHandler
    let margin : Margin

    before('load fixture', async () => {
        ({
            weth,
            usdc,
            asset,
            oracleRouter,
            router,
            tokenization,
            debtNFT,
            erc20Asset,
            syntheticFT,
            syntheticNFT,
            helper,
            simpleBorrower,
            lending,
            trigger,
            liquidation,
            liquidationBasic,
            liquidationAuction,
            triggerLogicStopLoss,
            triggerLogicTakeProfit,
            triggerLogicMaturity,
            mockTriggerHandler,
            margin
        } = await loadFixture(factorialFixture));


        const [signer] = await ethers.getSigners();
        const usdcAmount = BigNumber.from(10).pow(6).mul(3_000_000);
        const wethAmount = BigNumber.from(10).pow(18).mul(100_000);

        let depositCallData1 = lending.interface.encodeFunctionData("deposit",
            [usdc.address, usdcAmount]);
        await router.execute(MAX, lending.address, depositCallData1);
        
        let depositCallData2 = lending.interface.encodeFunctionData("deposit",
            [weth.address, wethAmount]);
        await router.execute(MAX, lending.address, depositCallData2);

    })

    describe('#1 margin simple test', async () => {
        it('#1-1 margin short', async () => {
            const [signer] = await ethers.getSigners();
            const wethAmount = BigNumber.from(10).pow(18).mul(5);
            const usdcAmount = BigNumber.from(10).pow(6).mul(10_000);

            const balance = await usdc.balanceOf(signer.address);
            const executeOpenWethShort = margin.interface.encodeFunctionData("open", [
                usdc.address, usdcAmount, weth.address, wethAmount
            ]);
            await router.execute(MAX, margin.address, executeOpenWethShort);
            expect(await usdc.balanceOf(signer.address)).to.be.equals(balance.sub(usdcAmount));

            const debtId = await helper.combineToId(8585218, (await debtNFT.sequentialN()).sub(1), lending.address);
            expect(await asset.ownerOf(debtId)).to.be.equals(signer.address);
            const tokenInfo = await debtNFT.tokenInfos(debtId);
            expect(tokenInfo.collateralAmount).to.be.equals(wethAmount.add(usdcAmount));
        });

        it('#1-1 margin short close', async () => {
            const [signer] = await ethers.getSigners();
            const debtId = await helper.combineToId(8585218, (await debtNFT.sequentialN()).sub(1), lending.address);

            const executeCloseWethShort = margin.interface.encodeFunctionData("close", [
                debtId
            ]);
            await router.execute(MAX, margin.address, executeCloseWethShort);
            expect(await asset.ownerOf(debtId)).to.be.equals(NO_ADDRESS);
        });

        // it('#1-2 trigger execute test', async () => {
        // });

        // it('#1-3 trigger cancel fail test', async () => {
        // });

        // it('#1-4 trigger cancel success test', async () => {
        // });

        // it("#1-5 trigger register liquidation test", async () => {
        // });

        // it('#1-6 trigger liquidation success', async() => {
        // });

        // it('#1-6 liquidation trigger fail', async() => {
        //     // no bidder 거나 bidAmount가 부족한경우 어케할지해야함.
        // });
    })
})
