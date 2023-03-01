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
    UniswapV2FT,
    TestHelper, FactorialRouter, FactorialAsset,
    SimpleBorrower, Lending, Trigger, Liquidation, LiquidationBasic, LiquidationAuction, TriggerLogicStopLoss
} from '../../typechain'
import {
    DEBT_NFT_TOKEN_TYPE,
    SYNTHETIC_FT_TOKEN_TYPE,
    SYNTHETIC_NFT_TOKEN_TYPE
} from "../constants";
import {address} from "hardhat/internal/core/config/config-validation";

const factorialFixture: Fixture<{
    weth: MockOldERC20
    usdc: MockOldERC20
    oracleRouter: OracleRouter
    router: FactorialRouter
    asset: FactorialAsset
    tokenization: Tokenization
    debtNFT: DebtNFT
    erc20Asset: ERC20Asset
    syntheticFT: SyntheticFT
    syntheticNFT: SyntheticNFT
    helper: TestHelper
    simpleBorrower: SimpleBorrower
    lending: Lending
    trigger: Trigger
    liquidation: Liquidation
    liquidationBasic: LiquidationBasic
    liquidationAuction: LiquidationAuction
    triggerLogicStopLoss: TriggerLogicStopLoss
}> = async () => {
    const [deployer, user1] = await ethers.getSigners();

    const MockERC20Factory = await ethers.getContractFactory('MockOldERC20');
    const OracleRouterFactory = await ethers.getContractFactory('OracleRouter');
    const SimplePriceOracleFactory = await ethers.getContractFactory('SimplePriceOracle');
    const FactorialRouterFactory = await ethers.getContractFactory('FactorialRouter');
    const FactorialAssetFactory = await ethers.getContractFactory('FactorialAsset');
    const TokenizationFactory = await ethers.getContractFactory('Tokenization');
    const DebtNFTFactory = await ethers.getContractFactory('DebtNFT');
    const ERC20AssetFactory = await ethers.getContractFactory('ERC20Asset');
    const SushiswapV2NFTFactory = await ethers.getContractFactory('SushiswapV2NFT');
    const SyntheticFTFactory = await ethers.getContractFactory('SyntheticFT');
    const SyntheticNFTFactory = await ethers.getContractFactory('SyntheticNFT');
    const UniswapV2FTFactory = await ethers.getContractFactory('UniswapV2FT');
    const testHelperFactory = await ethers.getContractFactory('TestHelper');

    const simpleBorrowerFactory = await ethers.getContractFactory('SimpleBorrower');
    const lendingFactory = await ethers.getContractFactory('Lending');
    const triggerFactory = await ethers.getContractFactory('Trigger');
    const liquidationFactory = await ethers.getContractFactory('Liquidation');
    const liquidationBasicFactory = await ethers.getContractFactory('LiquidationBasic');
    const liquidationAuctionFactory = await ethers.getContractFactory('LiquidationAuction');
    const triggerLogicStopLossFactory = await ethers.getContractFactory('TriggerLogicStopLoss');

    const weth = await MockERC20Factory.deploy("mockWETH", "WETH", "18") as MockOldERC20;
    const usdc = await MockERC20Factory.deploy("mockUSDC", "USDC", "6") as MockOldERC20;
    const oracleRouter = await OracleRouterFactory.deploy() as OracleRouter;
    const simplePriceOracle = await SimplePriceOracleFactory.deploy() as SimplePriceOracle;
    const router = await FactorialRouterFactory.deploy() as FactorialRouter;
    const asset = await FactorialAssetFactory.deploy() as FactorialAsset;
    const tokenization = await TokenizationFactory.deploy() as Tokenization;
    const debtNFT = await DebtNFTFactory.deploy() as DebtNFT;
    const erc20Asset = await ERC20AssetFactory.deploy() as ERC20Asset;
    const syntheticFT = await SyntheticFTFactory.deploy() as SyntheticFT;
    const syntheticNFT = await SyntheticNFTFactory.deploy() as SyntheticNFT;
    const helper = await testHelperFactory.deploy() as TestHelper;

    const trigger = await triggerFactory.deploy(tokenization.address, asset.address) as Trigger;
    const liquidation = await liquidationFactory.deploy(tokenization.address, debtNFT.address, trigger.address, asset.address) as Liquidation;
    const liquidationBasic = await liquidationBasicFactory.deploy(liquidation.address, tokenization.address, debtNFT.address) as LiquidationBasic;
    const liquidationAuction = await liquidationAuctionFactory.deploy(liquidation.address, tokenization.address, debtNFT.address, asset.address) as LiquidationAuction;
    const triggerLogicStopLoss = await triggerLogicStopLossFactory.deploy() as TriggerLogicStopLoss;
    // const lending = await lendingFactory.deploy(tokenization.address, debtNFT.address, trigger.address, asset.address, liquidation.address, liquidationBasic.address) as Lending;
    const lending = await lendingFactory.deploy() as Lending;
    
    // const simpleBorrower = await simpleBorrowerFactory.deploy(lending.address, debtNFT.address, debtNFT.address) as SimpleBorrower;
    const simpleBorrower = await simpleBorrowerFactory.deploy() as SimpleBorrower;
    
    await router.initialize(asset.address);
    await asset.initialize(router.address, tokenization.address);
    await tokenization.initialize(asset.address);
    await oracleRouter.initialize();
    await simplePriceOracle.initialize();
    await erc20Asset.initialize(oracleRouter.address);
    await debtNFT.initialize(tokenization.address, asset.address);
    await syntheticFT.initialize(tokenization.address, asset.address);
    await syntheticNFT.initialize(tokenization.address, asset.address);
    
    await lending.initialize(tokenization.address, debtNFT.address, trigger.address, asset.address, liquidation.address, liquidationBasic.address);
    
    await simpleBorrower.initialize(asset.address, lending.address, debtNFT.address, debtNFT.address);

    await lending.addBank(usdc.address);
    await lending.addBank(weth.address);

    await trigger.addTriggerLogic(triggerLogicStopLoss.address);
    
    await oracleRouter.setRoute(
        [usdc.address, weth.address],
        [simplePriceOracle.address, simplePriceOracle.address]
    );

    await weth.mint(deployer.address, "10000000000000000000000000");
    await weth.mint(user1.address, "10000000000000000000000000");

    await usdc.mint(deployer.address, "10000000000000000000000000");
    await usdc.mint(user1.address, "10000000000000000000000000");

    await weth.approve(asset.address, "10000000000000000000000000");
    await usdc.approve(asset.address, "10000000000000000000000000");

    await simplePriceOracle.setPrice(weth.address, '2000000000');
    await simplePriceOracle.setPrice(usdc.address, '1000000');

    await tokenization.registerTokenType(0, erc20Asset.address);
    await tokenization.registerTokenType(DEBT_NFT_TOKEN_TYPE, debtNFT.address);
    await tokenization.registerTokenType(SYNTHETIC_FT_TOKEN_TYPE, syntheticFT.address);
    await tokenization.registerTokenType(SYNTHETIC_NFT_TOKEN_TYPE, syntheticNFT.address);

    await asset.registerFactorialModules([
        router.address,
        tokenization.address,
        tokenization.address,
        debtNFT.address,
        erc20Asset.address,
        syntheticNFT.address,
        syntheticFT.address,
        liquidation.address,
        trigger.address
    ]);

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
        helper,
        simpleBorrower,
        lending,
        trigger,
        liquidation,
        liquidationBasic,
        liquidationAuction,
        triggerLogicStopLoss
    }
}

export default factorialFixture
