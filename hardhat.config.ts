import { HardhatUserConfig } from "hardhat/types";

import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import 'hardhat-typechain'
import 'hardhat-watcher'
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";

const DEFAULT_COMPILER_SETTINGS = {
  version: '0.8.12',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const config: HardhatUserConfig = {
  networks: {
      hardhat: {
          mining: {
              auto: true,
              interval: 2000,
          },
          forking: {
              url: "https://polygon-rpc.com"
          }
      },
      polygon: {
          url: "https://polygon-rpc.com",
          chainId: 137,
          gas: 1000000,
      },
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS]
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 250000000000,
  },
  watcher: {
    test: {
      tasks: [{ command: 'test', params: { testFiles: ['{path}'] } }],
      files: ['./test/**/*'],
      verbose: true,
    },
  },
}

export default config;