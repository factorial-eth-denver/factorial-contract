import {
    DEBT_NFT_TOKEN_TYPE, MaxUint128,
    SUSHI_NFT_TOKEN_TYPE,
    SYNTHETIC_FT_TOKEN_TYPE,
    SYNTHETIC_NFT_TOKEN_TYPE
} from "./constants";

const fs = require('fs');
import {ethers} from "hardhat";
import hre from 'hardhat'
import {
    AssetManagement, ChainlinkOracle,
    ConnectionPool,
    DebtNFT,
    ERC20Asset,
    FactorialRouter,
    MockERC20__factory,
    OracleRouter,
    SimplePriceOracle,
    SushiswapConnector,
    SushiswapV2NFT,
    SyntheticFT,
    SyntheticNFT,
    TestHelper,
    Tokenization, UniswapV2Oracle, WrappedNativeToken__factory,
    MockTriggerHandler, Margin, IUniswapV2Pair, IUniswapV2Router, LYF,
    SimpleBorrower, Lending, Trigger, Liquidation, LiquidationBasic, LiquidationAuction, TriggerLogicStopLoss, TriggerLogicTakeProfit, TriggerLogicMaturity, TriggerLogicLiquidate, WrappedNativeToken
} from "../typechain";

async function main() {
    // ----------------------file setting---------------------------------
    let readFileAddress = "../networks/" + hre.network.name + ".json";
    let writeFileAddress = "./networks/" + hre.network.name + ".json";

    const config = require(readFileAddress);

    if (config.TOKENIZATION == undefined) {
        console.log("not core contract deployed");
        return;
    }

    const [deployer, user1] = await ethers.getSigners();

    const simpleBorrowerFactory = await ethers.getContractFactory('SimpleBorrower');
    const lendingFactory = await ethers.getContractFactory('Lending');
    const triggerFactory = await ethers.getContractFactory('Trigger');
    const liquidationFactory = await ethers.getContractFactory('Liquidation');
    const liquidationBasicFactory = await ethers.getContractFactory('LiquidationBasic');
    const liquidationAuctionFactory = await ethers.getContractFactory('LiquidationAuction');
    const triggerLogicStopLossFactory = await ethers.getContractFactory('TriggerLogicStopLoss');
    const triggerLogicTakeProfitFactory = await ethers.getContractFactory('TriggerLogicTakeProfit');
    const triggerLogicMaturityFactory = await ethers.getContractFactory('TriggerLogicMaturity');
    const triggerLogicLiquidateFactory = await ethers.getContractFactory('TriggerLogicLiquidate');
    const mockTriggerHandlerFactory = await ethers.getContractFactory('MockTriggerHandler');
    const marginFactory = await ethers.getContractFactory('Margin');
    const lyfFactory = await ethers.getContractFactory('LYF');


    let wmatic = await WrappedNativeToken__factory.connect(config.WMATIC, deployer);
    let sushi = await MockERC20__factory.connect(config.SUSHI, deployer);
    let usdc = await MockERC20__factory.connect(config.USDC, deployer);
    let wmatic_usdc_lp = await MockERC20__factory.connect(config.SUSHI_WMATIC_USDC_LP, deployer);

    console.log("Deploy success ... 1/6 ");

    const trigger = await triggerFactory.deploy() as Trigger;
    const liquidation = await liquidationFactory.deploy() as Liquidation;
    const liquidationBasic = await liquidationBasicFactory.deploy(liquidation.address, config.TOKENIZATION, config.DEBT_NFT) as LiquidationBasic;
    const liquidationAuction = await liquidationAuctionFactory.deploy() as LiquidationAuction;
    const triggerLogicStopLoss = await triggerLogicStopLossFactory.deploy(config.TOKENIZATION) as TriggerLogicStopLoss;
    const triggerLogicTakeProfit = await triggerLogicTakeProfitFactory.deploy(config.TOKENIZATION) as TriggerLogicTakeProfit;
    const triggerLogicMaturity = await triggerLogicMaturityFactory.deploy() as TriggerLogicMaturity;
    const triggerLogicLiquidate = await triggerLogicLiquidateFactory.deploy(config.DEBT_NFT) as TriggerLogicLiquidate;
    const lending = await lendingFactory.deploy() as Lending;
    const simpleBorrower = await simpleBorrowerFactory.deploy() as SimpleBorrower;
    const mockTriggerHandler = await mockTriggerHandlerFactory.deploy() as MockTriggerHandler;
    const margin = await marginFactory.deploy() as Margin;
    const lyf = await lyfFactory.deploy() as LYF;

    console.log("Deploy success ... 2/6 ");

    await lending.initialize(config.TOKENIZATION, config.DEBT_NFT, trigger.address, config.ASSET_MANAGEMENT, liquidation.address, liquidationAuction.address);
    await simpleBorrower.initialize(
        config.TOKENIZATION,
        config.ASSET_MANAGEMENT,
        lending.address,
        config.SYNTHETIC_NFT,
        config.DEBT_NFT
    );
    await trigger.initialize(config.ASSET_MANAGEMENT, 20, 50);
    await liquidation.initialize(config.TOKENIZATION, config.DEBT_NFT, trigger.address, config.ASSET_MANAGEMENT);
    await liquidationAuction.initialize(liquidation.address, config.TOKENIZATION, config.DEBT_NFT, config.ASSET_MANAGEMENT);
    await margin.initialize(config.ASSET_MANAGEMENT, lending.address, config.DEBT_NFT, config.SUSHI_CONNECTOR);
    await lyf.initialize(config.ASSET_MANAGEMENT, config.LENDING, config.DEBT_NFT, config.SUSHI_CONNECTOR);
    
    await lending.addBank(usdc.address);
    await lending.addBank(wmatic.address);

    await trigger.addTriggerLogic(triggerLogicStopLoss.address);
    await trigger.addTriggerLogic(triggerLogicTakeProfit.address);
    await trigger.addTriggerLogic(triggerLogicMaturity.address);
    await trigger.addTriggerLogic(triggerLogicLiquidate.address);

    await liquidation.addModules([liquidationBasic.address, liquidationAuction.address]);

    console.log("Deploy success ... 6/6 ");

    config.TRIGGER = trigger.address;
    config.LIQUIDATION = liquidation.address;
    config.LIQUIDATION_AUCTION = liquidationAuction.address;
    config.LENDING = lending.address;
    config.MARGIN = margin.address;
    // ---------------------------write file-------------------------------
    fs.writeFileSync(writeFileAddress, JSON.stringify(config, null, 1));
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
