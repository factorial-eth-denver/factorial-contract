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
    FactorialRouter,
    SimpleBorrower, Lending, Trigger, Liquidation, LiquidationBasic, LiquidationAuction, TriggerLogicStopLoss
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture2 from "./fixture/factorialFixture2";
import {expect} from "chai";
import { BigNumber } from 'ethers';

const MAX96 = BigNumber.from(2).pow(90).sub(1);

describe('ERC20Asset wrapper unit test', () => {
    let weth: MockERC20
    let usdc: MockERC20
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
            const amount = 3000000e6;

            let depositCallData = lending.interface.encodeFunctionData("deposit",
                [usdc.address, amount]);
            await router.execute(MAX96, lending.address, depositCallData);
            
            const balance = await lending.balanceOf(signer.address, usdc.address);
            expect(balance).to.equal(amount);
        })

        it('#1-2 success withdraw test', async () => {
            const [signer] = await ethers.getSigners();
            const amount = 3000000e6;

            console.log("signer address : " + signer.address);

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

        it('#1-3 success borrow test', async () => {
            const [signer] = await ethers.getSigners();
            // const depositWethAmount = BigNumber.from(10).pow(18).mul(1000);
            const collateralAmount = 1000000e6;
            const borrowAmount = 1000000e6;

            let borrowCallData = simpleBorrower.interface.encodeFunctionData("borrow",
                [usdc.address, usdc.address, collateralAmount, borrowAmount])
            await router.execute(MAX96, simpleBorrower.address, borrowCallData);

            console.log("after borrow");

        //     // await simpleBorrower.borrow(usdc.address, usdc.address, collateralAmount, collateralAmount / 2);

        //     let wrapCallData = simpleBorrower.interface.encodeFunctionData("borrow",
        //         [usdc.address, usdc.address, collateralAmount, collateralAmount / 2])
        //         console.log("before router");
        //     await router.execute(MAX96, simpleBorrower.address, wrapCallData);
        //     console.log("after router2");
            
        })

        // it('#1-2 warp revert test', async () => {
        //     let [user1] = await ethers.getSigners();
        //     await expect(erc20Asset.wrap(user1.address, 12, "0x00")).to.be.revertedWith('Not supported')
        // })

        // it('#1-3 unwrap revert test', async () => {
        //     let [user1] = await ethers.getSigners();
        //     await expect(erc20Asset.unwrap(user1.address, 12,"0x00")).to.be.revertedWith('Not supported')
        // })
    })
})