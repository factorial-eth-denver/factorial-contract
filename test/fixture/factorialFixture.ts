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
    TestHelper, FactorialRouter, FactorialAsset
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
    asset: FactorialAsset
    tokenization: Tokenization
    debtNFT: DebtNFT
    erc20Asset: ERC20Asset
    syntheticFT: SyntheticFT
    syntheticNFT: SyntheticNFT
    helper: TestHelper
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
    const testHelperFactory = await ethers.getContractFactory('TestHelper');

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
    const sushiNFT = await SyntheticNFTFactory.deploy() as SushiswapV2NFT;
    const helper = await testHelperFactory.deploy() as TestHelper;

    await router.initialize(asset.address);
    await asset.initialize(router.address, tokenization.address);
    await tokenization.initialize(asset.address);
    await oracleRouter.initialize();
    await simplePriceOracle.initialize();
    await erc20Asset.initialize(oracleRouter.address);
    await debtNFT.initialize(tokenization.address, asset.address);
    await syntheticFT.initialize(tokenization.address, asset.address);
    await syntheticNFT.initialize(tokenization.address, asset.address);
    // await sushiNFT.initialize(tokenization.address, farm);

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

    await simplePriceOracle.setPrice(weth.address, '2000');
    await simplePriceOracle.setPrice(usdc.address, '1000000000000');

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
        syntheticFT.address
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
        helper
    }
}

export default factorialFixture
