import {
    MaxUint128, SUSHI_NFT_TOKEN_TYPE,
} from "./constants";

const fs = require('fs');
import {ethers} from "hardhat";
import hre from 'hardhat'
import {
    AssetManagement__factory, Connection__factory, ConnectionPool__factory, DebtNFT, DebtNFT__factory,
    FactorialRouter__factory,
    Lending__factory, Logging, Logging__factory,
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
    let lyf = await LYF__factory.connect(config.LEVERAGE_YIELD_FARMING, deployer);
    let debtNft = await DebtNFT__factory.connect(config.DEBT_NFT, deployer);

    let helper = await TestHelper__factory.connect(config.HELPER, deployer);

    let usdcId = await helper.convertAddressToId(usdc.address);
    let wethId = await helper.convertAddressToId(weth.address);
    //
    // const usdcAmount = BigNumber.from(10).pow(7).mul(2);
    // const wethAmount = BigNumber.from(10).pow(16).mul(1);
    // let depositCallData1 = lending.interface.encodeFunctionData("deposit",
    //     [usdc.address, usdcAmount]);
    // await router.execute(MaxUint128, lending.address, depositCallData1);
    // let depositCallData2 = lending.interface.encodeFunctionData("deposit",
    //     [weth.address, wethAmount]);
    // await router.execute(MaxUint128, lending.address, depositCallData2);
    //
    // let openCalldata = lyf.interface.encodeFunctionData("open",
    //     [[usdcId, wethId], [usdcAmount, wethAmount], usdcId, usdcAmount.div(2)]);
    // await router.execute(MaxUint128, lyf.address, openCalldata);

    let loggingAddress = await lyf.logging();
    let logging = await Logging__factory.connect(loggingAddress, deployer);

    const loggingFactory = await ethers.getContractFactory('Logging');
    let logging2 = await loggingFactory.deploy() as Logging;
    await logging2.initialize(config.DEBT_NFT,config.LENDING);
    let test = await logging.tokens(deployer.address, 0)
    await logging2.add(deployer.address, test, false);
    console.log(await debtNft.tokenInfos(test));
    console.log(await logging2.getStatus(deployer.address));

    // ---------------------------write file-------------------------------
    fs.writeFileSync(writeFileAddress, JSON.stringify(config, null, 1));
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
