import {ethers} from 'hardhat';
import {
    DebtNFT,
    ERC20Asset,
    AssetManagement,
    FactorialRouter,
    MockERC20,
    OracleRouter,
    SyntheticFT,
    SyntheticNFT, TestHelper,
    Tokenization
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture from "./fixture/factorialFixture";
import {expect} from "chai";
import {SYNTHETIC_FT_TOKEN_TYPE, SYNTHETIC_NFT_TOKEN_TYPE} from "./shared/constants";

describe('SyntheticNFT wrapper unit test', () => {
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
    let helper: TestHelper

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
            helper
        } = await loadFixture(factorialFixture));
    })

    describe('#1 NFT simple test', async () => {
        it('#1-1 wrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let wrapParam = ethers.utils.AbiCoder.prototype.encode(
                ['uint256[]', 'uint256[]'],
                [[usdcId, wethId], ["1000000", "1000000000000000000"]]
            );

            let wrapCallData = tokenization.interface.encodeFunctionData("wrap",
                [SYNTHETIC_NFT_TOKEN_TYPE, wrapParam])
            await router.execute(1000000, tokenization.address, wrapCallData);
        })

        it('#1-2 getValue after wrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let sequentialN = await syntheticNFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_NFT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            expect(await asset.balanceOf(syntheticNFT.address, usdcId)).to.equal("1000000");
            expect(await asset.balanceOf(syntheticNFT.address, wethId)).to.equal("1000000000000000000");
            expect((await syntheticNFT.getTokenInfo(synthTokenId)).amounts[0].toString()).to.equal("1000000");
            expect((await syntheticNFT.getTokenInfo(synthTokenId)).amounts[1].toString()).to.equal("1000000000000000000");
            expect(await syntheticNFT.getValue(synthTokenId, 1)).to.equal("2001000000000000000000");
        })

        it('#1-3 unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticNFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_NFT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            await tokenization.unwrap(synthTokenId, 1);
        })

        it('#1-4 getValue after unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticNFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_NFT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            expect(await syntheticNFT.getValue(synthTokenId, 1)).to.equal(0);
        })
    })

    describe('#2 FT test', async () => {
        it('#2-1 wrap FT success test', async () => {
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let wrapParam = ethers.utils.AbiCoder.prototype.encode(
                ['uint256[]', 'uint256[]', 'uint256', 'uint256'],
                [[usdcId, wethId], ["1000000", "1000000000000000000"], 0, 10000]
            );
            let wrapCallData = tokenization.interface.encodeFunctionData("wrap",
                [SYNTHETIC_FT_TOKEN_TYPE, wrapParam])
            await router.execute(1000000, tokenization.address, wrapCallData);
        })

        it('#2-2 getValue after wrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let sequentialN = await syntheticFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            expect(await asset.balanceOf(syntheticFT.address, usdcId)).to.equal("1000000");
            expect(await asset.balanceOf(syntheticFT.address, wethId)).to.equal("1000000000000000000");
            expect((await syntheticFT.getTokenInfo(synthTokenId)).amounts[0].toString()).to.equal("1000000");
            expect((await syntheticFT.getTokenInfo(synthTokenId)).amounts[1].toString()).to.equal("1000000000000000000");
            expect(await syntheticFT.getValue(synthTokenId, 10000)).to.equal("2001000000000000000000");
        })

        it('#2-3 unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            await tokenization.unwrap(synthTokenId, 9000);
        })

        it('#2-4 getValue after unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            expect(await syntheticFT.getValue(synthTokenId, 1000)).to.equal("200100000000000000000");
        })

        it('#2-5 unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            await tokenization.unwrap(synthTokenId, 1000);
        })
    })
})