import {
    DEBT_NFT_TOKEN_TYPE, MaxUint128,
    SUSHI_NFT_TOKEN_TYPE,
    SYNTHETIC_FT_TOKEN_TYPE,
    SYNTHETIC_NFT_TOKEN_TYPE
} from "../test/shared/constants";

const fs = require('fs');
import {ethers} from "hardhat";
import hre from 'hardhat'
import {
    AssetManagement,
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
    Tokenization, UniswapV2Oracle, WrappedNativeToken__factory
} from "../typechain";

async function main() {
    const [owner] = await ethers.getSigners();

    // ----------------------file setting---------------------------------
    let readFileAddress = "../networks/" + hre.network.name + ".json";
    let writeFileAddress = "./networks/" + hre.network.name + ".json";

    const config = require(readFileAddress);

    const [deployer, user1] = await ethers.getSigners();

    const OracleRouterFactory = await ethers.getContractFactory('OracleRouter');
    const SimplePriceOracleFactory = await ethers.getContractFactory('SimplePriceOracle');
    const UniswapV2OracleFactory = await ethers.getContractFactory('UniswapV2Oracle');
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

    let wmatic = await WrappedNativeToken__factory.connect(config.WMATIC, deployer);
    let sushi = await MockERC20__factory.connect(config.SUSHI, deployer);
    let usdc = await MockERC20__factory.connect(config.USDC, deployer);
    let wmatic_usdc_lp = await MockERC20__factory.connect(config.SUSHI_WMATIC_USDC_LP, deployer);

    console.log("Deploy success ... 1/6 ");
    const oracleRouter = await OracleRouterFactory.deploy() as OracleRouter;
    const simplePriceOracle = await SimplePriceOracleFactory.deploy() as SimplePriceOracle;
    const uniswapV2Oracle = await UniswapV2OracleFactory.deploy() as UniswapV2Oracle;
    const router = await FactorialRouterFactory.deploy() as FactorialRouter;
    const asset = await AssetManagementFactory.deploy() as AssetManagement;
    const tokenization = await TokenizationFactory.deploy() as Tokenization;
    const debtNFT = await DebtNFTFactory.deploy() as DebtNFT;
    const erc20Asset = await ERC20AssetFactory.deploy() as ERC20Asset;
    const syntheticFT = await SyntheticFTFactory.deploy() as SyntheticFT;
    const syntheticNFT = await SyntheticNFTFactory.deploy() as SyntheticNFT;
    const connectionPool = await ConnectionPoolFactory.deploy() as ConnectionPool;
    const sushiNFT = await SushiswapV2NFTFactory.deploy() as SushiswapV2NFT;
    const sushiConnector = await SushiConnectorFactory.deploy() as SushiswapConnector;
    const helper = await testHelperFactory.deploy() as TestHelper;

    console.log("Deploy success ... 2/6 ");
    await router.initialize(asset.address);
    await asset.initialize(router.address, tokenization.address);
    await tokenization.initialize(asset.address);
    await oracleRouter.initialize();
    await simplePriceOracle.initialize();
    await uniswapV2Oracle.initialize(oracleRouter.address);
    await erc20Asset.initialize(oracleRouter.address);
    await debtNFT.initialize(tokenization.address, asset.address);
    await syntheticFT.initialize(tokenization.address, asset.address);
    await syntheticNFT.initialize(tokenization.address, asset.address);
    await connectionPool.initialize(asset.address);
    await sushiNFT.initialize(tokenization.address, config.SUSHI_MINICHEF);

    console.log("Deploy success ... 3/6 ");
    await sushi.approve(asset.address, MaxUint128);
    await usdc.approve(asset.address, MaxUint128);
    await wmatic.approve(asset.address, MaxUint128);
    await wmatic_usdc_lp.approve(asset.address, MaxUint128);

    await oracleRouter.setRoute(
        [usdc.address, wmatic.address, sushi.address, wmatic_usdc_lp.address],
        [simplePriceOracle.address, simplePriceOracle.address, simplePriceOracle.address, uniswapV2Oracle.address]
    );

    await simplePriceOracle.setPrice(wmatic.address, '2000');
    await simplePriceOracle.setPrice(usdc.address, '1000000000000');
    await simplePriceOracle.setPrice(sushi.address, '1000000000');
    await simplePriceOracle.setPrice(wmatic_usdc_lp.address, uniswapV2Oracle.address);

    console.log("Deploy success ... 4/6 ");
    await tokenization.registerTokenType(0, erc20Asset.address);
    await tokenization.setGuideTokenFactor(wmatic.address, 9000, 11000);
    await tokenization.setGuideTokenFactor(usdc.address, 9000, 11000);
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

    console.log("Deploy success ... 5/6 ");
    await connectionPool.increaseConnection(10);
    await connectionPool.increaseConnection(10);
    await connectionPool.increaseConnection(10);

    await asset.registerFactorialModules([sushiConnector.address]);
    await sushiConnector.initialize(tokenization.address, asset.address, connectionPool.address, config.SUSHI_MINICHEF, config.SUSHI_ROUTER, SUSHI_NFT_TOKEN_TYPE);
    await connectionPool.registerConnector(sushiConnector.address);


    /// Optional
    await wmatic.deposit({value: "100000000000000000000"});

    let usdcId = await helper.convertAddressToId(usdc.address);
    let wmaticId = await helper.convertAddressToId(wmatic.address);
    let sellCalldata = sushiConnector.interface.encodeFunctionData("sell",
        [wmaticId, usdcId, "5000000000000000000", 0])
    await router.execute(MaxUint128, sushiConnector.address, sellCalldata);

    console.log("Deploy success ... 6/6 ");
    config.ADMIN = owner.address;
    config.ORACLE_ROUTER = oracleRouter.address;
    config.SIMPLE_PRICE_ORACLE = simplePriceOracle.address;
    config.UNI_V2_ORACLE = uniswapV2Oracle.address;
    config.FACTORIAL_ROUTER = router.address;
    config.ASSET_MANAGEMENT = asset.address;
    config.TOKENIZATION = tokenization.address;
    config.DEBT_NFT = debtNFT.address;
    config.ERC20_ASSET = erc20Asset.address;
    config.SYNTHETIC_FT = syntheticFT.address;
    config.SYNTHETIC_NFT = syntheticNFT.address;
    config.CONNECTION_POOL = connectionPool.address;
    config.SUSHI_CONNECTOR = sushiConnector.address;
    config.HELPER = helper.address;

    // ---------------------------write file-------------------------------
    fs.writeFileSync(writeFileAddress, JSON.stringify(config, null, 1));
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
