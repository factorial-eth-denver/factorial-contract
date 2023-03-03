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
    FactorialRouter, MockTriggerHandler, ITriggerLogic,
    SimpleBorrower, Lending, Trigger, Liquidation, LiquidationBasic, LiquidationAuction, TriggerLogicStopLoss, TriggerLogicTakeProfit, TriggerLogicMaturity, FactorialAsset
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture2 from "./fixture/factorialFixture2";
import {expect} from "chai";
import { BigNumber } from 'ethers';

const MAX = BigNumber.from(2).pow(250).sub(1);
const NO_ADDRESS = "0x0000000000000000000000000000000000000000";

describe('Trigger unit test', () => {
    let weth: MockERC20
    let usdc: MockERC20
    let asset: FactorialAsset
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
            mockTriggerHandler
        } = await loadFixture(factorialFixture2));

        // const [signer] = await ethers.getSigners();
        // const usdcAmount = BigNumber.from(10).pow(6).mul(3_000_000);
        // const wethAmount = BigNumber.from(10).pow(18).mul(100_000);

        // let depositCallData1 = lending.interface.encodeFunctionData("deposit",
        //     [usdc.address, usdcAmount]);
        // await router.execute(MAX, lending.address, depositCallData1);
        
        // const balance = await lending.balanceOf(signer.address, usdc.address);
        // expect(balance).to.equal(usdcAmount);

        // let depositCallData2 = lending.interface.encodeFunctionData("deposit",
        //     [weth.address, wethAmount]);
        // await router.execute(MAX, lending.address, depositCallData2);


        // const collateralAmount = BigNumber.from(10).pow(6).mul(10_000);
        // const borrowAmount = BigNumber.from(10).pow(18).mul(30);

        // let borrowCallData = simpleBorrower.interface.encodeFunctionData("borrow",
        //     [usdc.address, collateralAmount, weth.address, borrowAmount])
        // await router.execute(MAX, simpleBorrower.address, borrowCallData);

    })

    describe('#1 trigger simple test', async () => {
        it('#1-1 trigger register success test', async () => {
            const [signer] = await ethers.getSigners();

            const stopLossId = 1; // StopLoss
            const takeProfitId = 2; // TakeProfit
            const maturityId = 3; // Maturity
            const collateralAsset = weth.address;
            const collateralAmount = BigNumber.from(10).pow(18).mul(1);
            const stopLoss = BigNumber.from(2).pow(256).sub(1);
            
            const max = BigNumber.from(2).pow(256).sub(1);
            const min = BigNumber.from(2).pow(1).sub(1);

            let maxValueCheckData = triggerLogicStopLoss.interface.encodeFunctionData("check",
                [ethers.utils.AbiCoder.prototype.encode(['uint256', 'uint256', 'uint256'], [collateralAsset, collateralAmount, max])]);
            let minValueCheckData = triggerLogicStopLoss.interface.encodeFunctionData("check",
                [ethers.utils.AbiCoder.prototype.encode(['uint256', 'uint256', 'uint256'], [collateralAsset, collateralAmount, min])]);
            let maxCheckData = triggerLogicStopLoss.interface.encodeFunctionData("check",
                [ethers.utils.AbiCoder.prototype.encode(['uint256'], [max])]);
            let minCheckData = triggerLogicStopLoss.interface.encodeFunctionData("check",
                [ethers.utils.AbiCoder.prototype.encode(['uint256'], [min])]);

            let triggerExecuteData = ethers.utils.AbiCoder.prototype.encode(
                ['uint256','uint256','uint256','uint256'],
                [10, 20, 40, 50]
            );
            const triggerCallData = mockTriggerHandler.interface.encodeFunctionData("trigger",
                [triggerExecuteData]
            );

            function createCalldata(triggerId: number, checkData: string) {
                return trigger.interface.encodeFunctionData("registerTrigger",
                    [
                        signer.address,
                        collateralAsset,
                        collateralAmount,
                        triggerId,
                        checkData,
                        mockTriggerHandler.address,
                        triggerCallData
                    ]);
            }

            let stopMaxCalldata = createCalldata(stopLossId, maxValueCheckData);
            await router.execute(MAX, trigger.address, stopMaxCalldata);

            let stopMinCalldata = createCalldata(stopLossId, minValueCheckData);
            await router.execute(MAX, trigger.address, stopMinCalldata);

            let takeMaxCalldata = createCalldata(takeProfitId, maxValueCheckData);
            await router.execute(MAX, trigger.address, takeMaxCalldata);

            let takeMinCalldata = createCalldata(takeProfitId, minValueCheckData);
            await router.execute(MAX, trigger.address, takeMinCalldata);

            let maturityMaxCalldata = createCalldata(maturityId, maxCheckData);
            await router.execute(MAX, trigger.address, maturityMaxCalldata);

            let maturityMinCalldata = createCalldata(maturityId, minCheckData);
            await router.execute(MAX, trigger.address, maturityMinCalldata);

            const stopMaxKey = 0;
            const stopMinKey = 1;
            const takeMaxKey = 2;
            const takeMinKey = 3;
            const maturityMaxKey = 4;
            const maturityMinKey = 5;

            expect((await trigger.triggerInfos(stopMaxKey)).owner).to.be.equals(signer.address);
            expect((await trigger.triggerInfos(stopMinKey)).owner).to.be.equals(signer.address);

            expect((await trigger.triggerInfos(takeMaxKey)).owner).to.be.equals(signer.address);
            expect((await trigger.triggerInfos(takeMinKey)).owner).to.be.equals(signer.address);

            expect((await trigger.triggerInfos(maturityMaxKey)).owner).to.be.equals(signer.address);
            expect((await trigger.triggerInfos(maturityMinKey)).owner).to.be.equals(signer.address);
        });

        it('#1-2 trigger execute test', async () => {
            const [signer, user2] = await ethers.getSigners();

            const stopMaxKey = 0;
            const stopMinKey = 1;
            const takeMaxKey = 2;
            const takeMinKey = 3;
            const maturityMaxKey = 4;
            const maturityMinKey = 5;

            let triggerExecuteData = ethers.utils.AbiCoder.prototype.encode(
                ['uint256'], [0]
            );
            let checkData = await trigger.checkUpkeep(triggerExecuteData);
            expect(checkData.upkeepNeeded).to.be.equals(true);
            if (checkData.upkeepNeeded) {
                await trigger.performUpkeep(checkData.performData);
            }
            checkData = await trigger.checkUpkeep(triggerExecuteData);
            expect(checkData.upkeepNeeded).to.be.equals(false);

            expect((await trigger.triggerInfos(stopMaxKey)).owner).to.be.equals(NO_ADDRESS);
            expect((await trigger.triggerInfos(stopMinKey)).owner).to.be.equals(signer.address);
            expect((await trigger.triggerInfos(takeMaxKey)).owner).to.be.equals(signer.address);
            expect((await trigger.triggerInfos(takeMinKey)).owner).to.be.equals(NO_ADDRESS);
            expect((await trigger.triggerInfos(maturityMaxKey)).owner).to.be.equals(signer.address);
            expect((await trigger.triggerInfos(maturityMinKey)).owner).to.be.equals(NO_ADDRESS);
        });

        it('#1-3 trigger cancel fail test', async () => {
            const [signer, user2] = await ethers.getSigners();

            expect(trigger.connect(user2).cancelTrigger(1)).to.be.revertedWith("Not Owner");

            expect(trigger.cancelTrigger(0)).to.be.revertedWith("Not Owner");
            expect(trigger.cancelTrigger(3)).to.be.revertedWith("Not Owner");
            expect(trigger.cancelTrigger(5)).to.be.revertedWith("Not Owner");
            expect(trigger.cancelTrigger(6)).to.be.revertedWith("Not Owner");
            expect(trigger.cancelTrigger(7)).to.be.revertedWith("Not Owner");
        });

        it('#1-4 trigger cancel success test', async () => {
            const [signer] = await ethers.getSigners();
            
            await trigger.cancelTrigger(1);
            await trigger.cancelTrigger(2);
            await trigger.cancelTrigger(4);

            expect((await trigger.triggerInfos(1)).owner).to.be.equals(NO_ADDRESS);
            expect((await trigger.triggerInfos(2)).owner).to.be.equals(NO_ADDRESS);
            expect((await trigger.triggerInfos(4)).owner).to.be.equals(NO_ADDRESS);
        });

        it("#1-5 trigger register liquidation test", async () => {
            const [signer] = await ethers.getSigners();
            const usdcAmount = BigNumber.from(10).pow(6).mul(3_000_000);
            const wethAmount = BigNumber.from(10).pow(18).mul(100_000);

            // DEPOST LENDING
            let depositCallData1 = lending.interface.encodeFunctionData("deposit", [usdc.address, usdcAmount]);
            await router.execute(MAX, lending.address, depositCallData1);
            let depositCallData2 = lending.interface.encodeFunctionData("deposit", [weth.address, wethAmount]);
            await router.execute(MAX, lending.address, depositCallData2);


            const collateralAmount = BigNumber.from(10).pow(6).mul(10_000);
            const borrowAmount = BigNumber.from(10).pow(18).mul(30);

            let borrowCallData = simpleBorrower.interface.encodeFunctionData("borrow",
                [usdc.address, collateralAmount, weth.address, borrowAmount])
            await router.execute(MAX, simpleBorrower.address, borrowCallData);

            expect((await trigger.triggerInfos(0)).owner).to.be.equals(lending.address);
        });

        it('#1-5 trigger liquidation success', async() => {
            const [signer, user2] = await ethers.getSigners();
            const collId = "58800697922810017650787290564883328417794666055230440537919107614380168924797";
            const debtId = "59252996967900590458033039854761061520142434331456584512406121919203549201468";
            const bidAmount = BigNumber.from(10).pow(18).mul(31);

            let executeBid = liquidationAuction.interface
                .encodeFunctionData("bid", [debtId, bidAmount]);
            await router.execute(MAX, liquidationAuction.address, executeBid);

            let triggerExecuteData = ethers.utils.AbiCoder.prototype.encode(
                ['uint256'], [0]
            );
            let beforeBalance = await asset.balanceOf(signer.address, collId);
            let checkData = await trigger.checkUpkeep(triggerExecuteData);
            expect(checkData.upkeepNeeded).to.be.equals(true);
            if (checkData.upkeepNeeded) {
                await trigger.performUpkeep(checkData.performData);
            }
            checkData = await trigger.checkUpkeep(triggerExecuteData);
            expect(checkData.upkeepNeeded).to.be.equals(false);
            expect((await trigger.triggerInfos(0)).owner).to.be.equals(NO_ADDRESS);
            expect((await asset.balanceOf(signer.address, collId)).sub(beforeBalance)).to.be.equals(1);
        });

        it('#1-6 liquidation trigger fail', async() => {
            // no bidder 거나 bidAmount가 부족한경우 어케할지해야함.
        });
    })
})