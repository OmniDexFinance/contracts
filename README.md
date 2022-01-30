# contracts
OmniDex Contracts





Sensei.sol :

Background
The Pancakeswap smart contracts were adapted to create the OmniDex DeFi platform. These
contracts include a migration capability which was also inherited by the Omnidex ZenMaster
contract. This migration functionality has the undesirable consequence of potentially allowing a
malicious contract owner to take control of all investments on the platform. In order to reinforce
trust and confidence in the platform the developers wish to permanently remove this capability.

Approach
The direct removal of the migrator code from the already deployed ZenMaster contract was deemed
to be complex, risky and could lead to a very poor user experience. The proposed approach is
therefore to permanently disable this code by making it inaccessible to all users, devs and owners.
Critically, the migration functionality within the ZenMaster contract is only accessible to the owner
of the contract through the ‘onlyOwner’ parameter. This attribute of the contract will be used to
permanently disable the vulnerability.

Solution
In order to overcome the challenge, a new proxy router contract, Sensei.sol, will be created and this
contract will become the new owner of the ZenMaster contract. The purpose of Sensei will be to
route all ‘ownerOnly’ calls to the ZenMaster and, as the owner of the ZenMaster, Sensei will be the
only entity that is permitted to call these functions. Critically, the functions that provide access to
the migrator functionality will not be relayed thus making them inaccessible to all.
In addition to this, the ‘transferOwner’ function inherited by the ZenMaster will also NOT be relayed
by Sensei making Sensei the permanent owner of ZenMaster. It will be possible to transfer
ownership of the Sensei contract which, in effect, will transfer ownership of the ZenMaster but with
the restricted access described above.
Most importantly, the OmniDex application front end does not make any calls to ‘onlyOwner’
functions and therefore will not be impacted by this change.
OnlyOwner Functions Relayed by Sensei

• updateMultiplier – updates the bonus multiplier
• add - adds a new LP token
• Set - Updates the pool allocation points

Conclusion
The method outlined above describes a solution that will disable the migrator vulnerability without
disrupting the user experience. The change will be permanent and there will be no way to reinvoke
the excluded functions in the future. The solution has already been tested within a test environment
where it successfully disabled the unwanted functionality without impacting the user application.
The next steps will be to validate and deploy whilst in parallel seeking a full audit of all contracts.
