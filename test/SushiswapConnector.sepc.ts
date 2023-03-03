import {ethers} from 'hardhat';
import {
    AssetManagement, ConnectionPool,
    DebtNFT,
    ERC20Asset, FactorialRouter,
    MockERC20, MockOldERC20, MockSushi,
    OracleRouter, SushiswapConnector, SushiswapV2NFT,
    SyntheticFT,
    SyntheticNFT,
    TestHelper,
    Tokenization
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture from "./fixture/factorialFixture";
import {MaxUint128, SUSHI_NFT_TOKEN_TYPE, SYNTHETIC_NFT_TOKEN_TYPE} from "./shared/constants";

describe('Sushiswap Connector unit test', () => {
    let weth: MockERC20
    let usdc: MockERC20
    let oracleRouter: OracleRouter
    let router: FactorialRouter
    let asset: AssetManagement
    let tokenization: Tokenization
    let debtNFT: DebtNFT
    let erc20Asset: ERC20Asset
    let syntheticFT: SyntheticFT
    let syntheticNFT: SyntheticNFT
    let connectionPool: ConnectionPool
    let helper: TestHelper
    let sushiConnector: SushiswapConnector

    before('load fixture', async () => {
        ({
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
            helper
        } = await loadFixture(factorialFixture));

    })

    describe('#1 simple test', async () => {
        it('#1-1 buy success test', async () => {
            let [user1] = await ethers.getSigners();
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let buyCalldata = sushiConnector.interface.encodeFunctionData("buy",
                [usdcId, wethId, 1000000, 0])
            await router.execute(MaxUint128, sushiConnector.address, buyCalldata);
        })

        it('#1-2 sell success test', async () => {
            let [user1] = await ethers.getSigners();
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let sellCalldata = sushiConnector.interface.encodeFunctionData("sell",
                [usdcId, wethId, 1000000, 0])
            await router.execute(MaxUint128, sushiConnector.address, sellCalldata);
        })


        it('#1-3 sell success test', async () => {
            let [user1] = await ethers.getSigners();
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let sellCalldata = sushiConnector.interface.encodeFunctionData("depositNew",
                [usdcId, 1000000])
            await router.execute(MaxUint128, sushiConnector.address, sellCalldata);
        })
    })
})