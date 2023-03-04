import { BigNumber } from 'ethers'

export const MaxUint128 = BigNumber.from(2).pow(128).sub(1)
export const MaxUint16 = BigNumber.from(2).pow(16).sub(1)
export const ZeroAddress = "0x0000000000000000000000000000000000000000"
export const NFT = BigNumber.from(2).pow(23)

export const DEBT_NFT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(3).add(2).add(NFT)
export const SYNTHETIC_FT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(2).add(3)
export const SYNTHETIC_NFT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(2).add(4).add(NFT)
export const SUSHI_NFT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(2).add(5).add(NFT)


export enum FeeAmount {
    LOW = 500,
    MEDIUM = 3000,
    HIGH = 10000,
}

export const TICK_SPACINGS: { [amount in FeeAmount]: number } = {
    [FeeAmount.LOW]: 10,
    [FeeAmount.MEDIUM]: 60,
    [FeeAmount.HIGH]: 200,
}
