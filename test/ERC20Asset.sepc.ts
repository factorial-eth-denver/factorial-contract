import {ethers} from 'hardhat';
import {
    DebtNFT,
    ERC20Asset,
    MockERC20,
    OracleRouter,
    SyntheticFT,
    SyntheticNFT,
    TestHelper,
    Tokenization
} from '../typechain';
import {loadFixture} from "ethereum-waffle";
import factorialFixture from "./fixture/factorialFixture";
import {expect} from "chai";

describe('ERC20Asset wrapper unit test', () => {
    let weth: MockERC20
    let usdc: MockERC20
    let oracleRouter: OracleRouter
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
            tokenization,
            debtNFT,
            erc20Asset,
            syntheticFT,
            syntheticNFT,
            helper
        } = await loadFixture(factorialFixture));
    })

    describe('#1 wrap simple test', async () => {
        it('#1-1 success test', async () => {
            let usdcId = await helper.convertAddressToId(usdc.address);
            expect(await erc20Asset.getValue(usdcId, 100)).to.equal(100000000);
        })

        it('#1-2 warp revert test', async () => {
            let [user1] = await ethers.getSigners();
            await expect(erc20Asset.wrap(user1.address, 12, "0x00")).to.be.revertedWith('Not supported')
        })

        it('#1-3 unwrap revert test', async () => {
            let [user1] = await ethers.getSigners();
            await expect(erc20Asset.unwrap(user1.address, 12,"0x00")).to.be.revertedWith('Not supported')
        })
    })
})