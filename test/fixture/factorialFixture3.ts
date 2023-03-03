import {Fixture} from 'ethereum-waffle'
import {ethers} from 'hardhat'
import {
    MockOldERC20,
    ERC20Asset,
    OracleRouter,
    SimplePriceOracle,
    Tokenization,
    DebtNFT,
    SushiswapV2NFT,
    SyntheticFT,
    SyntheticNFT,
    TestHelper,
    FactorialRouter,
    AssetManagement, ConnectionPool, MockSushi, SushiswapConnector,
    //////////// weather //////////////
    MockTriggerHandler, Margin,
    SimpleBorrower, Lending, Trigger, Liquidation, LiquidationBasic, LiquidationAuction, TriggerLogicStopLoss, TriggerLogicTakeProfit, TriggerLogicMaturity, TriggerLogicLiquidate
    //////////// weather //////////////
} from '../../typechain'
import {
    DEBT_NFT_TOKEN_TYPE,
    SYNTHETIC_FT_TOKEN_TYPE,
    SYNTHETIC_NFT_TOKEN_TYPE,
    SUSHI_NFT_TOKEN_TYPE
} from "../shared/constants";
import {address} from "hardhat/internal/core/config/config-validation";

const factorialFixture: Fixture<{
    weth: MockOldERC20
    usdc: MockOldERC20
    oracleRouter: OracleRouter
    router: FactorialRouter
    asset: AssetManagement
    tokenization: Tokenization
    debtNFT: DebtNFT
    erc20Asset: ERC20Asset
    syntheticFT: SyntheticFT
    syntheticNFT: SyntheticNFT
    connectionPool: ConnectionPool
    sushiConnector: SushiswapConnector
    helper: TestHelper
    //////////// weather //////////////
    simpleBorrower: SimpleBorrower
    lending: Lending
    trigger: Trigger
    liquidation: Liquidation
    liquidationBasic: LiquidationBasic
    liquidationAuction: LiquidationAuction
    triggerLogicStopLoss: TriggerLogicStopLoss
    triggerLogicTakeProfit: TriggerLogicTakeProfit
    triggerLogicMaturity: TriggerLogicMaturity
    mockTriggerHandler: MockTriggerHandler
    margin: Margin
    //////////// weather //////////////

}> = async () => {
    const [deployer, user1] = await ethers.getSigners();

    const MockERC20Factory = await ethers.getContractFactory('MockOldERC20');
    const OracleRouterFactory = await ethers.getContractFactory('OracleRouter');
    const SimplePriceOracleFactory = await ethers.getContractFactory('SimplePriceOracle');
    const FactorialRouterFactory = await ethers.getContractFactory('FactorialRouter');
    const AssetManagementFactory = await ethers.getContractFactory('AssetManagement');
    const TokenizationFactory = await ethers.getContractFactory('Tokenization');
    const DebtNFTFactory = await ethers.getContractFactory('DebtNFT');
    const ERC20AssetFactory = await ethers.getContractFactory('ERC20Asset');
    const SyntheticFTFactory = await ethers.getContractFactory('SyntheticFT');
    const SyntheticNFTFactory = await ethers.getContractFactory('SyntheticNFT');
    const ConnectionPoolFactory = await ethers.getContractFactory('ConnectionPool');
    const testHelperFactory = await ethers.getContractFactory('TestHelper');
    const SushiConnectorFactory = await ethers.getContractFactory('SushiswapConnector');
    const SushiswapV2NFTFactory = await ethers.getContractFactory('SushiswapV2NFT');
    const MockSushiFactory = await ethers.getContractFactory('MockSushi');

    //////////// weather //////////////
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
    //////////// weather //////////////

    const weth = await MockERC20Factory.deploy("mockWETH", "WETH", "18") as MockOldERC20;
    const usdc = await MockERC20Factory.deploy("mockUSDC", "USDC", "6") as MockOldERC20;
    const sushi = await MockERC20Factory.deploy("mockSushi", "SUSHI", "18") as MockOldERC20;
    const sushiLP = await MockERC20Factory.deploy("mockSushiLP", "LP", "18") as MockOldERC20;
    const oracleRouter = await OracleRouterFactory.deploy() as OracleRouter;
    const simplePriceOracle = await SimplePriceOracleFactory.deploy() as SimplePriceOracle;
    const router = await FactorialRouterFactory.deploy() as FactorialRouter;
    const asset = await AssetManagementFactory.deploy() as AssetManagement;
    const tokenization = await TokenizationFactory.deploy() as Tokenization;
    const debtNFT = await DebtNFTFactory.deploy() as DebtNFT;
    const erc20Asset = await ERC20AssetFactory.deploy() as ERC20Asset;
    const syntheticFT = await SyntheticFTFactory.deploy() as SyntheticFT;
    const syntheticNFT = await SyntheticNFTFactory.deploy() as SyntheticNFT;
    const connectionPool = await ConnectionPoolFactory.deploy() as ConnectionPool;
    const sushiNFT = await SushiswapV2NFTFactory.deploy() as SushiswapV2NFT;
    const mockSushi = await MockSushiFactory.deploy(sushi.address, sushiLP.address) as MockSushi;
    const sushiConnector = await SushiConnectorFactory.deploy() as SushiswapConnector;
    const helper = await testHelperFactory.deploy() as TestHelper;

    //////////// weather //////////////
    const trigger = await triggerFactory.deploy() as Trigger;
    const liquidation = await liquidationFactory.deploy() as Liquidation;
    const liquidationBasic = await liquidationBasicFactory.deploy(liquidation.address, tokenization.address, debtNFT.address) as LiquidationBasic;
    const liquidationAuction = await liquidationAuctionFactory.deploy() as LiquidationAuction;
    const triggerLogicStopLoss = await triggerLogicStopLossFactory.deploy(tokenization.address) as TriggerLogicStopLoss;
    const triggerLogicTakeProfit = await triggerLogicTakeProfitFactory.deploy(tokenization.address) as TriggerLogicTakeProfit;
    const triggerLogicMaturity = await triggerLogicMaturityFactory.deploy() as TriggerLogicMaturity;
    const triggerLogicLiquidate = await triggerLogicLiquidateFactory.deploy(debtNFT.address) as TriggerLogicLiquidate;
    const lending = await lendingFactory.deploy() as Lending;
    const simpleBorrower = await simpleBorrowerFactory.deploy() as SimpleBorrower;
    const mockTriggerHandler = await mockTriggerHandlerFactory.deploy() as MockTriggerHandler;
    const margin = await marginFactory.deploy() as Margin;
    //////////// weather //////////////
    

    await router.initialize(asset.address);
    await asset.initialize(router.address, tokenization.address);
    await tokenization.initialize(asset.address);
    await oracleRouter.initialize();
    await simplePriceOracle.initialize();
    await erc20Asset.initialize(oracleRouter.address);
    await debtNFT.initialize(tokenization.address, asset.address);
    await syntheticFT.initialize(tokenization.address, asset.address);
    await syntheticNFT.initialize(tokenization.address, asset.address);
    await connectionPool.initialize(asset.address);
    await sushiNFT.initialize(tokenization.address, mockSushi.address);


    //////////// weather //////////////
    await lending.initialize(tokenization.address, debtNFT.address, trigger.address, asset.address, liquidation.address, liquidationAuction.address);
    await simpleBorrower.initialize(
        tokenization.address,
        asset.address,
        lending.address,
        syntheticNFT.address,
        debtNFT.address
    );
    await trigger.initialize(asset.address, 20, 50);
    await liquidation.initialize(tokenization.address, debtNFT.address, trigger.address, asset.address);
    await liquidationAuction.initialize(liquidation.address, tokenization.address, debtNFT.address, asset.address);
    await margin.initialize(asset.address, lending.address, debtNFT.address, sushiConnector.address);

    await lending.addBank(usdc.address);
    await lending.addBank(weth.address);

    await trigger.addTriggerLogic(triggerLogicStopLoss.address);
    await trigger.addTriggerLogic(triggerLogicTakeProfit.address);
    await trigger.addTriggerLogic(triggerLogicMaturity.address);
    await trigger.addTriggerLogic(triggerLogicLiquidate.address);

    await liquidation.addModules([liquidationBasic.address, liquidationAuction.address]);
    //////////// weather //////////////


    await oracleRouter.setRoute(
        [usdc.address, weth.address, sushi.address, sushiLP.address],
        [simplePriceOracle.address, simplePriceOracle.address, simplePriceOracle.address, simplePriceOracle.address]
    );

    await weth.mint(deployer.address, "100000000000000000000000000");
    await weth.mint(user1.address, "100000000000000000000000000");

    await usdc.mint(deployer.address, "10000000000000000");
    await usdc.mint(user1.address, "10000000000000000");

    await weth.approve(asset.address, "1000000000000000000000000000000");
    await usdc.approve(asset.address, "10000000000000000000000000000000");

    await sushi.mint(deployer.address, "10000000000000000000000");
    await sushiLP.mint(user1.address, "10000000000000000000000");
    await sushi.mint(mockSushi.address, "1000000000000000000000");
    await sushiLP.mint(mockSushi.address, "1000000000000000000000");
    await sushi.approve(asset.address, "1000000000000000000000000000000");
    await sushiLP.approve(asset.address, "10000000000000000000000000000000");
    await usdc.mint(mockSushi.address, "10000000000000000000000000");
    await weth.mint(mockSushi.address, "1000000000000000000000000000000");

    await simplePriceOracle.setPrice(weth.address, '2000');
    await simplePriceOracle.setPrice(usdc.address, '1000000000000');
    await simplePriceOracle.setPrice(sushi.address, '1000000000');
    await simplePriceOracle.setPrice(sushiLP.address, '1000000000');

    await tokenization.registerTokenType(0, erc20Asset.address);
    await tokenization.setGuideTokenFactor(weth.address.toString(), 9000, 11000);
    await tokenization.setGuideTokenFactor(usdc.address.toString(), 9000, 11000);
    await tokenization.registerTokenType(DEBT_NFT_TOKEN_TYPE, debtNFT.address);
    await tokenization.setGuideTokenFactor(DEBT_NFT_TOKEN_TYPE, 9000, 11000);
    await tokenization.registerTokenType(SYNTHETIC_FT_TOKEN_TYPE, syntheticFT.address);
    await tokenization.setGuideTokenFactor(SYNTHETIC_FT_TOKEN_TYPE, 9000, 11000);
    await tokenization.registerTokenType(SYNTHETIC_NFT_TOKEN_TYPE, syntheticNFT.address);
    await tokenization.setGuideTokenFactor(SYNTHETIC_NFT_TOKEN_TYPE, 9000, 11000);
    await tokenization.registerTokenType(SUSHI_NFT_TOKEN_TYPE, syntheticNFT.address);
    await tokenization.setGuideTokenFactor(SUSHI_NFT_TOKEN_TYPE, 9000, 11000);

    await asset.registerFactorialModules([
        router.address,
        tokenization.address,
        tokenization.address,
        debtNFT.address,
        erc20Asset.address,
        syntheticNFT.address,
        syntheticFT.address,
        connectionPool.address
    ]);

    await connectionPool.increaseConnection(5);

    await asset.registerFactorialModules([sushiConnector.address]);
    // Change connectionPool address
    await sushiConnector.initialize(tokenization.address, asset.address, connectionPool.address, mockSushi.address, mockSushi.address, SUSHI_NFT_TOKEN_TYPE);
    await connectionPool.registerConnector(sushiConnector.address);

    return {
        weth,
        usdc,
        oracleRouter,
        router,
        asset,
        tokenization,
        debtNFT,
        erc20Asset,
        syntheticFT,
        syntheticNFT,
        connectionPool,
        sushiConnector,
        helper,
        //////////// weather //////////////
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
        margin,
        //////////// weather //////////////

    }
}

export default factorialFixture
