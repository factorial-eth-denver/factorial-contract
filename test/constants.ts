import { BigNumber } from 'ethers'

export const MaxUint128 = BigNumber.from(2).pow(128).sub(1)
export const MaxUint16 = BigNumber.from(2).pow(16).sub(1)
export const ZeroAddress = "0x0000000000000000000000000000000000000000"

export const DEBT_FT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(2).add(1)
export const DEBT_NFT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(2).add(2)
export const SYNTHETIC_FT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(2).add(3)
export const SYNTHETIC_NFT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(2).add(4)
export const TRIGGER_NFT_TOKEN_TYPE = BigNumber.from(2).pow(16).mul(3).add(1)
