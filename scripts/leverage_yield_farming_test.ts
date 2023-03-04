import {
    MaxUint128, SUSHI_NFT_TOKEN_TYPE,
} from "./constants";

const fs = require('fs');
import {ethers} from "hardhat";
import hre from 'hardhat'
import {
    AssetManagement__factory, Connection__factory, ConnectionPool__factory,
    FactorialRouter__factory,
    Lending__factory,
    LYF,
    LYF__factory,
    MockERC20__factory,
    OracleRouter__factory,
    SushiswapConnector,
    SushiswapConnector__factory,
    TestHelper__factory,
    Tokenization__factory,
    WrappedNativeToken__factory
} from "../typechain";
import {BigNumber} from "ethers";

async function main() {
    // ----------------------file setting---------------------------------
    let readFileAddress = "../networks/" + hre.network.name + ".json";
    let writeFileAddress = "./networks/" + hre.network.name + ".json";

    const config = require(readFileAddress);

    const [deployer, user1] = await ethers.getSigners();

    let weth = await MockERC20__factory.connect(config.WETH, deployer);
    let usdc = await MockERC20__factory.connect(config.USDC, deployer);
    let lending = await Lending__factory.connect(config.LENDING, deployer);
    let tokenization = await Tokenization__factory.connect(config.TOKENIZATION, deployer);
    let connectionPool = await ConnectionPool__factory.connect(config.CONNECTION_POOL, deployer);
    let asset = await AssetManagement__factory.connect(config.ASSET_MANAGEMENT, deployer);
    let router = await FactorialRouter__factory.connect(config.FACTORIAL_ROUTER, deployer);
    let oracle = await OracleRouter__factory.connect(config.ORACLE_ROUTER, deployer);

    const lyfFactory = await ethers.getContractFactory('LYF');

    let helper = await TestHelper__factory.connect(config.HELPER, deployer);

    let usdcId = await helper.convertAddressToId(usdc.address);
    let wethId = await helper.convertAddressToId(weth.address);

    const SushiConnectorFactory = await ethers.getContractFactory('SushiswapConnector');
    const sushiConnector = await SushiConnectorFactory.deploy() as SushiswapConnector;
    await asset.registerFactorialModules([sushiConnector.address]);
    await sushiConnector.initialize(tokenization.address, asset.address, connectionPool.address, config.SUSHI_MINICHEF, config.SUSHI_ROUTER, SUSHI_NFT_TOKEN_TYPE);
    await connectionPool.registerConnector(sushiConnector.address);

    const usdcAmount = BigNumber.from(10).pow(7).mul(2);
    const wethAmount = BigNumber.from(10).pow(16).mul(1);
    let depositCallData1 = lending.interface.encodeFunctionData("deposit",
        [usdc.address, usdcAmount]);
    await router.execute(MaxUint128, lending.address, depositCallData1);
    let depositCallData2 = lending.interface.encodeFunctionData("deposit",
        [weth.address, wethAmount]);
    await router.execute(MaxUint128, lending.address, depositCallData2);


    await sushiConnector.setPools(await helper.convertAddressToId(config.SUSHI_WETH_USDC_LP), 1);
    console.log("####"+await oracle.getPrice(config.USDC));
    console.log("####"+await oracle.getPrice(config.WETH));
    console.log("####"+await oracle.getPrice(config.SUSHI_WETH_USDC_LP));

    console.log("@@@@"+await tokenization.getValueAsDebt(deployer.address, config.USDC, usdcAmount));
    console.log("@@@@"+await tokenization.getValueAsDebt(deployer.address, config.WETH, wethAmount));
    console.log("@@@@"+await tokenization.getValueAsCollateral(deployer.address, config.SUSHI_WETH_USDC_LP, wethAmount));
    const lyf = await lyfFactory.deploy() as LYF;
    await lyf.initialize(config.ASSET_MANAGEMENT, config.LENDING, config.DEBT_NFT, sushiConnector.address);
    let openCalldata = lyf.interface.encodeFunctionData("open",
        [[usdcId, wethId], [usdcAmount, wethAmount], usdcId, usdcAmount.div(2)]);
    await router.execute(MaxUint128, lyf.address, openCalldata);

    // ---------------------------write file-------------------------------
    fs.writeFileSync(writeFileAddress, JSON.stringify(config, null, 1));
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
