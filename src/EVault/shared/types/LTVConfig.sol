// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Errors} from "../Errors.sol";
import {ConfigAmount} from "./Types.sol";
import {LTVType} from "./LTVType.sol";
import "../Constants.sol";

struct LTVConfig {
    uint40 targetTimestamp;
    ConfigAmount targetLTV;
    uint24 rampDuration;
    ConfigAmount originalLTV;
    bool initialized; // flag is se
}

library LTVConfigLib {
    function isRecognizedCollateral(LTVConfig memory self) internal pure returns (bool) {
        return self.targetTimestamp != 0;
    }

    function getLTV(LTVConfig memory self, LTVType ltvType) internal view returns (ConfigAmount) {
        if (ltvType == LTVType.BORROWING || block.timestamp >= self.targetTimestamp) return self.targetLTV;

        uint256 ltv = self.originalLTV.toUint16();

        unchecked {
            uint256 timeElapsed = self.rampDuration - (self.targetTimestamp - block.timestamp);

            if (self.targetLTV > self.originalLTV) {
                ltv += ((self.targetLTV.toUint16() - self.originalLTV.toUint16()) * timeElapsed / self.rampDuration);
            } else {
                ltv -= ((self.originalLTV.toUint16() - self.targetLTV.toUint16()) * timeElapsed / self.rampDuration);
            }
        }

        return ConfigAmount.wrap(uint16(ltv));
    }

    function setLTV(LTVConfig memory self, ConfigAmount targetLTV, uint24 rampDuration) internal view returns (LTVConfig memory newLTV) {
        newLTV.targetTimestamp = uint40(block.timestamp + rampDuration);
        newLTV.targetLTV = targetLTV;
        newLTV.rampDuration = rampDuration;
        newLTV.originalLTV = self.getLTV(LTVType.LIQUIDATION);
        newLTV.initialized = true;
    }

    function clear(LTVConfig storage self) internal {
        self.targetTimestamp = 0;
        self.targetLTV = ConfigAmount.wrap(0);
        self.rampDuration = 0;
        self.originalLTV = ConfigAmount.wrap(0);
    }
}

using LTVConfigLib for LTVConfig global;
