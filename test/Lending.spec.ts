import {ethers} from 'hardhat';
import {
    DebtNFT,
    ERC20Asset,
    AssetManagement,
    MockERC20,
    OracleRouter,
    SyntheticFT,
    SyntheticNFT,
    TestHelper,
    Tokenization,
    FactorialRouter,
    SimpleBorrower, Lending, Trigger, Liquidation, LiquidationBasic, LiquidationAuction, TriggerLogicStopLoss
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture2 from "./fixture/factorialFixture2";
import {expect} from "chai";
import { BigNumber } from 'ethers';

const MAX96 = BigNumber.from(2).pow(250).sub(1);

describe('Lending unit test', () => {
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
            triggerLogicStopLoss
        } = await loadFixture(factorialFixture2));
    })

    describe('#1 lending simple test', async () => {
        it('#1-1 success deposit test', async () => {
            const [signer] = await ethers.getSigners();
            const usdcAmount = BigNumber.from(10).pow(6).mul(3_000_000);
            const wethAmount = BigNumber.from(10).pow(18).mul(100_000);

            let depositCallData1 = lending.interface.encodeFunctionData("deposit",
                [usdc.address, usdcAmount]);
            await router.execute(MAX96, lending.address, depositCallData1);
            
            const balance = await lending.balanceOf(signer.address, usdc.address);
            expect(balance).to.equal(usdcAmount);

            let depositCallData2 = lending.interface.encodeFunctionData("deposit",
                [weth.address, wethAmount]);
            await router.execute(MAX96, lending.address, depositCallData2);
        })

        it('#1-2 success withdraw test', async () => {
            const [signer] = await ethers.getSigners();
            const amount = 3_000_000e6;

            const beforeBalance = await usdc.balanceOf(signer.address);

            let depositCallData = lending.interface.encodeFunctionData("deposit",
                [usdc.address, amount]);
            await router.execute(MAX96, lending.address, depositCallData);

            expect(await usdc.balanceOf(signer.address)).to.equal(beforeBalance.sub(amount));

            let withdrawCallData = lending.interface.encodeFunctionData("withdraw",
                [usdc.address, amount]);
            await router.execute(MAX96, lending.address, withdrawCallData);

            expect(await usdc.balanceOf(signer.address)).to.equal(beforeBalance);
        })

        it('#1-3 fail borrow - over debt', async () => {
            const [signer] = await ethers.getSigners();
            const collateralAmount = BigNumber.from(10).pow(6).mul(10_000);
            const borrowAmount = BigNumber.from(10).pow(18).mul(50);

            let borrowCallData = simpleBorrower.interface.encodeFunctionData("borrow",
                [usdc.address, collateralAmount, weth.address, borrowAmount])
            await expect(router.execute(MAX96, simpleBorrower.address, borrowCallData))
                .to.be.revertedWith('Lending: insufficient collateral')
        })


        it('#1-4 success borrow', async () => {
            const [signer] = await ethers.getSigners();
            const collateralAmount = BigNumber.from(10).pow(6).mul(10_000);
            const borrowAmount = BigNumber.from(10).pow(18).mul(10);

            let borrowCallData = simpleBorrower.interface.encodeFunctionData("borrow",
                [usdc.address, collateralAmount, weth.address, borrowAmount])
            await router.execute(MAX96, simpleBorrower.address, borrowCallData);

            const debtId = await helper.combineToId(8585218, (await debtNFT.sequentialN()).sub(1), lending.address);
            expect(await asset.balanceOf(signer.address, debtId)).to.equal(1);
        })

        it('#1-5 success repay', async () => {
            const [signer] = await ethers.getSigners();
            const debtId = await helper.combineToId(8585218, (await debtNFT.sequentialN()).sub(1), lending.address);

            const collInfo = await debtNFT.tokenInfos(debtId);
            const syntInfo = await syntheticNFT.getTokenInfo(collInfo.collateralToken);
            const debtInfo = await lending.getDebt(debtId);
            const beforeUsdc = await usdc.balanceOf(signer.address);
            const beforeWeth = await weth.balanceOf(signer.address);

            let repayCallData = simpleBorrower.interface.encodeFunctionData("repay",
                [debtId])
            await router.execute(MAX96, simpleBorrower.address, repayCallData);
            const afterUsdc = await usdc.balanceOf(signer.address);
            const afterWeth = await weth.balanceOf(signer.address);
            
            expect(beforeUsdc.add(syntInfo.amounts[0])).to.equals(afterUsdc);
            // 수수료까지 정확히예측 못해서 이렇게함.
            expect(beforeWeth.add(syntInfo.amounts[0]).sub(debtInfo[1])).to.lte(afterWeth);
        })

        // it('#1-6 success liquidate', async () => {
        //     const [signer] = await ethers.getSigners();
        //     const collateralAmount = BigNumber.from(10).pow(6).mul(10_000);
        //     const borrowAmount = BigNumber.from(10).pow(18).mul(30);

        //     let borrowCallData = simpleBorrower.interface.encodeFunctionData("borrow",
        //         [usdc.address, collateralAmount, weth.address, borrowAmount])
        //     await router.execute(MAX96, simpleBorrower.address, borrowCallData);

        //     const debtId = await helper.combineToId(8585218, (await debtNFT.sequentialN()).sub(1), lending.address);
        //     expect(await asset.balanceOf(signer.address, debtId)).to.equal(1);

        //     const debtInfo = await debtNFT.tokenInfos(debtId);

        //     const beforeDebtBalance = await weth.balanceOf(signer.address);
        //     const beforeCollBalance = await asset.balanceOf(signer.address, debtInfo.collateralToken);

        //     expect(beforeCollBalance).to.be.equals(0);

        //     let liquidateCalldata = lending.interface.encodeFunctionData("liquidate",
        //         [debtId])
        //     await router.execute(MAX96, lending.address, liquidateCalldata);

        //     const afterDebtBalance = await weth.balanceOf(signer.address);
        //     const afterCollBalance = await asset.balanceOf(signer.address, debtInfo.collateralToken);
            
        //     expect(beforeDebtBalance).to.be.gt(afterDebtBalance);
        //     expect(afterCollBalance).to.be.equals(1);
        // })
    })
})
