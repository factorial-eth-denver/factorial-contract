import {ethers} from 'hardhat';
import {
    DebtNFT,
    ERC20Asset,
    MockERC20,
    OracleRouter,
    SyntheticFT,
    SyntheticNFT, TestHelper,
    Tokenization,
    TriggerNFT
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture from "./fixture/factorialFixture";
import {expect} from "chai";
import {SYNTHETIC_FT_TOKEN_TYPE} from "./constants";

describe('SyntheticFT wrapper unit test', () => {
    let weth: MockERC20
    let usdc: MockERC20
    let oracleRouter: OracleRouter
    let tokenization: Tokenization
    let debtNFT: DebtNFT
    let erc20Asset: ERC20Asset
    let syntheticFT: SyntheticFT
    let syntheticNFT: SyntheticNFT
    let triggerNFT: TriggerNFT
    let helper: TestHelper

    before('load fixture', async () => {
        ({
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
        } = await loadFixture(factorialFixture));
    })

    describe('#1 simple test', async () => {
        it('#1-1 wrap success test', async () => {
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let wrapParam = ethers.utils.AbiCoder.prototype.encode(
                ['uint256[]', 'uint256[]', 'uint256', 'uint256'],
                [[usdcId, wethId], [10000, 10000], 0, 10000 ]
            );
            await tokenization.wrap(SYNTHETIC_FT_TOKEN_TYPE, wrapParam);
        })

        it('#1-2 getValue after wrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let usdcId = await helper.convertAddressToId(usdc.address);
            let wethId = await helper.convertAddressToId(weth.address);
            let sequentialN = await syntheticFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            expect(await tokenization.balanceOf(syntheticFT.address, wethId)).to.equal(10000);
            expect(await tokenization.balanceOf(syntheticFT.address, usdcId)).to.equal(10000);
            expect((await syntheticFT.getTokenInfo(synthTokenId)).amounts[0].toString()).to.equal("10000");
            expect((await syntheticFT.getTokenInfo(synthTokenId)).amounts[1].toString()).to.equal("10000");
            expect(await syntheticFT.getValue(synthTokenId, 10000)).to.equal(20010000000000);
        })

        it('#1-3 unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticFT.sequentialN();
            let unwrapParam = ethers.utils.AbiCoder.prototype.encode(
                ['uint256'],
                [9000]
            );
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            await tokenization.unwrap(synthTokenId, unwrapParam);
        })

        it('#1-4 getValue after unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticFT.sequentialN();
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            expect(await syntheticFT.getValue(synthTokenId, 1000)).to.equal(2001000000000);
        })

        it('#1-5 unwrap success test', async () => {
            let [user1] = await ethers.getSigners();
            let sequentialN = await syntheticFT.sequentialN();
            let unwrapParam = ethers.utils.AbiCoder.prototype.encode(
                ['uint256'],
                [1000]
            );
            let synthTokenId
                = await helper.combineToId(SYNTHETIC_FT_TOKEN_TYPE, sequentialN.sub(1), user1.address);
            await tokenization.unwrap(synthTokenId, unwrapParam);
        })
    })
})