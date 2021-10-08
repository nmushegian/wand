

New primitive `Wand` aka `DSProxy 2.0`

A `Wand` is a variation of the Proxy pattern with some differences and extra features

## `canCast` authorization

* The authorization pattern for access controlled calls (non-root/owner callers) has 
changed from DSProxy. Instead of using `DSAuth` to access control the proxy object itself,
`root` (owner) retains sole access to true "root" functions (transfer and update authority),
while `cast` applies the `canCast` access control table to the *spell being cast*. Concretely:

`canCall(address caller, address object, bytes4 sig) -> (bool)`

which was used like 

```
function exec(address target, bytes calldata data) returns (bytes ret) {
  assert authority.canCall(msg.sender, address(this), msg.sig)`
  ...
}
```

becomes

```
`canCast(address caller, address spell, bytes4 sig)`
```

which is called like 

```
function cast(address spell, bytes calldata data) returns (bool ok, bytes ret) {
  assert auth.canCast(msg.sender, spell, data[0:4]);
  ...
}
```
## protected `root` and `auth`

* caller-saved owner (`root`) and permission table (`auth`) makes spells
somewhat safer to use.

```
address root_ = root;  
address auth_ = auth;   

// this is in a fresh context, the local execution stack is not visible
(bit, ret) = spell.delegatecall(data);

require(auth == auth_, 'ERR_SUDO');
require(root == root_, 'ERR_SUDO')
```
 (The remaining loss of root control danger lies in `SELFDESTRUCT`,
which is easier to statically detect
(mitigated in future by
[https://eips.ethereum.org/EIPS/eip-2937](EIP-2937),
or any way to detect that code has been scheduled for selfdestruct)

## reentry `lock` and caller reference

* reentry lock saves the caller in storage and exposes it via function,
for access from both the spell being run external contracts. It is zero'd
for gas savings and consistency between spells

```
lock = msg.sender;
...

lock = ZERO;   
```

## spell (library) `code` reference

* the code being delegatecalled (the spell that was `cast`) is also saved
in storage so that the spell knows the actual contract object which has
the code being run (libraries do not have a "library object" reference, but
they could! These would be like singleton stateful libraries). It is also zero'd
after each cast (and/but is "caller save" for spells calling spells)

```
code = spell;
...

code = ZERO;   
```

