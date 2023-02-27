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
    TriggerNFT,
    UniswapV2FT,
    TestHelper
} from '../../typechain'
import {
    DEBT_FT_TOKEN_TYPE,
    DEBT_NFT_TOKEN_TYPE,
    SYNTHETIC_FT_TOKEN_TYPE,
    SYNTHETIC_NFT_TOKEN_TYPE,
    TRIGGER_NFT_TOKEN_TYPE
} from "../constants";

const factorialFixture: Fixture<{
    weth: MockOldERC20
    usdc: MockOldERC20
    oracleRouter: OracleRouter
    tokenization: Tokenization
    debtNFT: DebtNFT
    erc20Asset: ERC20Asset
    syntheticFT: SyntheticFT
    syntheticNFT: SyntheticNFT
    triggerNFT: TriggerNFT
    helper: TestHelper
}> = async () => {
    const [deployer, user1] = await ethers.getSigners();

    const MockERC20Factory = await ethers.getContractFactory('MockOldERC20');
    const OracleRouterFactory = await ethers.getContractFactory('OracleRouter');
    const SimplePriceOracleFactory = await ethers.getContractFactory('SimplePriceOracle');
    const TokenizationFactory = await ethers.getContractFactory('Tokenization');
    const DebtNFTFactory = await ethers.getContractFactory('DebtNFT');
    const ERC20AssetFactory = await ethers.getContractFactory('ERC20Asset');
    const SushiswapV2NFTFactory = await ethers.getContractFactory('SushiswapV2NFT');
    const SyntheticFTFactory = await ethers.getContractFactory('SyntheticFT');
    const SyntheticNFTFactory = await ethers.getContractFactory('SyntheticNFT');
    const TriggerNFTFactory = await ethers.getContractFactory('TriggerNFT');
    const UniswapV2FTFactory = await ethers.getContractFactory('UniswapV2FT');
    const testHelperFactory = await ethers.getContractFactory('TestHelper');

    const weth = await MockERC20Factory.deploy("mockWETH", "WETH", "18") as MockOldERC20;
    const usdc = await MockERC20Factory.deploy("mockUSDC", "USDC", "6") as MockOldERC20;
    const oracleRouter = await OracleRouterFactory.deploy() as OracleRouter;
    const simplePriceOracle = await SimplePriceOracleFactory.deploy() as SimplePriceOracle;
    const tokenization = await TokenizationFactory.deploy() as Tokenization;
    const debtNFT = await DebtNFTFactory.deploy() as DebtNFT;
    const erc20Asset = await ERC20AssetFactory.deploy() as ERC20Asset;
    const syntheticFT = await SyntheticFTFactory.deploy() as SyntheticFT;
    const syntheticNFT = await SyntheticNFTFactory.deploy() as SyntheticNFT;
    const triggerNFT = await TriggerNFTFactory.deploy() as TriggerNFT;
    const helper = await testHelperFactory.deploy() as TestHelper;

    await tokenization.initialize();
    await oracleRouter.initialize();
    await simplePriceOracle.initialize();
    await erc20Asset.initialize(oracleRouter.address);
    await debtNFT.initialize(tokenization.address);
    await syntheticFT.initialize(tokenization.address);
    await syntheticNFT.initialize(tokenization.address);
    await triggerNFT.initialize(tokenization.address);

    await oracleRouter.setRoute(
        [usdc.address, weth.address],
        [simplePriceOracle.address, simplePriceOracle.address]
    );

    await weth.mint(deployer.address, "100000000000000000000000");
    await weth.mint(user1.address, "100000000000000000000000");

    await usdc.mint(deployer.address, "100000000000000000000000");
    await usdc.mint(user1.address, "100000000000000000000000");

    await weth.approve(tokenization.address, "100000000000000000000000");
    await usdc.approve(tokenization.address, "100000000000000000000000");

    await simplePriceOracle.setPrice(weth.address, '2000000000');
    await simplePriceOracle.setPrice(usdc.address, '1000000');

    await tokenization.registerTokenType(0, erc20Asset.address);
    await tokenization.registerTokenType(DEBT_NFT_TOKEN_TYPE, debtNFT.address);
    await tokenization.registerTokenType(SYNTHETIC_FT_TOKEN_TYPE, syntheticFT.address);
    await tokenization.registerTokenType(SYNTHETIC_NFT_TOKEN_TYPE, syntheticNFT.address);
    await tokenization.registerTokenType(TRIGGER_NFT_TOKEN_TYPE, triggerNFT.address);

    return {
        weth,
        usdc,
        oracleRouter,
        tokenization,
        debtNFT,
        erc20Asset,
        syntheticFT,
        syntheticNFT,
        triggerNFT,
        helper
    }
}

export default factorialFixture
