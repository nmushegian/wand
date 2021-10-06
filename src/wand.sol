// SPDX-License-Identifier: AGPL-3.0

// Proxy with caller-saved auth / script-singleton access

// (C) 2021 A group of mysterious wizards
// (C) 2016-2020 DSProxy contributors https://github.com/dapphub/ds-proxy

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.6;

interface WandAuth {
  function canCast(address witch, address spell, bytes4 sigil)
    external returns (bool);
}

contract Wand {
  address public root;
  address public auth;
  address public code;
  address public lock;

  function cast(address spell, bytes calldata data)
    payable public
      returns (bool bit, bytes memory ret)
  {
    require(lock == ZERO, 'ERR_LOCK');
    lock = msg.sender;

    bytes4 sigil; assembly{ sigil := calldataload(data.offset) }

    if (msg.sender != root) {
      require(auth != ZERO, 'ERR_ROOT');
      require(WandAuth(auth).canCast(msg.sender, spell, sigil), 'ERR_AUTH');
    }  

    code = spell;   
    address root_ = root;  
    address auth_ = auth;   

    (bit, ret) = spell.delegatecall(data);  

    if (msg.sender != root) {
      require(root == root_, 'ERR_SET_ROOT');
      require(auth == auth_, 'ERR_SET_AUTH');
    }
    code = ZERO;   
    lock = ZERO;   

    // // This doesn't work, but ideally there's some way to detect selfdestruct
    // uint256 size; assembly { size := codesize(); }
    // require(size > 0, 'ERR_BOOM');

    assembly{ log4(caller(), spell, sigil, bit, 0, 0) }
  }

  function give(address dest) public {
    require(lock == ZERO, 'ERR_LOCK');
    require(msg.sender == root, 'ERR_GIVE');
    root = dest;
    assembly{ log3(caller(), 'give', dest, 0, 0) }
  }

  function bind(address what) public {
    require(lock == ZERO, 'ERR_LOCK');
    require(msg.sender == root, 'ERR_BIND');
    auth = what;
    assembly{ log3(caller(), 'bind', what, 0, 0) }
  }

  constructor() {
    root = msg.sender;
    assembly{ log3(0, 'give', caller(), 0, 0) }
  }

  address constant internal ZERO = address(0);
}

contract WandFactory {
  mapping(address=>bool) builtHere;
  function build() public returns (Wand wand) {
    wand = new Wand();
    wand.give(msg.sender);
    builtHere[address(wand)] = true;
    emit Build(address(wand));
  }
  event Build(address indexed wand);
}
