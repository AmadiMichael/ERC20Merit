# **ERC20 ALLOCATIONS (Time-weighted Aggregated Shares)**

### - **ERC20 token with an Onchain loyalty oracle**

### - **An ERC20 extension for trustlessly attributing perks/privileges to token holders based on their holdings over time.**

ERC20 Allocations is an extension of the widely used ERC20 token standard. It provides functionality that automatically tracks and stores data that can be used to calculate the "hodlership" of an address for that token. Specifically, this extension introduces a new concept called a "allocation coefficient", which is of type `uint256` and is distributed to token holders on a per-second basis based on the percentage of the total supply each user owns at that given second. This ensures that the allocation coefficient of each token holder is proportionate to their stake in the project and over time. Removing the ability for addresses with financial capacity from atomically taking advantage of the perks of holding a token for a short period of time.

This data is stored permanently onchain and can be queried by other smart contracts to determine the top token holders or simply an address's loyalty to that token within a given period of time. To do this, one needs to retrieve the total allocation distributed as of the start and en`d of the given period, as well as the allocation coefficients of each token holder we wish to check for at those times. With this information, we can accurately calculate the allocations for each token holder during the given period as a percentage (allocation(user) / total allocation distributed) since this would just be an aggregate of each users allocations per second within that time frame.

### **Under the hood, to get the allocations of an address between timestamps 100 and 200, we;**

- Get the total allocations distributed between time 100 and 200 by calling `totalAllocationsBetween(tokenAddress, 100, 200)`. Under the hood this gets the total allocations distributed as at timestamps 100 and 200 and subtracts the latter from the former.
- Get the allocations earned by the address in question between time 100 and 200 by calling `allocatedBetween(tokenAddress, userAddress, 100, 200)`. Under the hood this gets the allocations earned by the user as at timestamps 100 and 200 and subtracts the latter from the former.
- Both data can be queried individually and used as a fraction for calculating anything. DAO voting rights, Airdrop distribution, hold to earn reward distribution.
- The allocations of a user or total allocation distributed at a given time can be queried individually too not just between ranges for other use cases.

There are several potential use cases for ERC20 Allocations. For example, this data can be used for fair governance voting by allowing token holders to vote in proportion to their loyalty and stake in the project over time, rather than randomly or based on the amount of tokens held at a single timestamp. It can also be used for airdrop distribution based on the loyalty of another token's holders. Additionally, this data can be used for hold-to-earn reward distribution without requiring users to stake their tokens ("Liquid staking" if you will), which reduces the risks associated with staking if the staking contract is compromised.

Overall, ERC20 Allocations is a powerful extension of the ERC20 token standard that provides permanent, on-chain data about token holder loyalty and stake. This data has numerous potential use cases and can provide a more fair, transparent, and secure way of distributing rewards and making governance decisions within blockchain projects.

# **How it works**

For efficiently calculating the "allocation coefficient" of any given address, ERC20 Allocations use a similar model as Synthetix's staking rewards contract

$$
A(u, x, y) =  \left( \sum_{b}^{a} \frac {B}{T}\right) = AR . B \left( \sum_{t = 0}^{y - 1} \frac {1}{T} - \sum_{t = 0}^{x - 1} \frac {1}{T}
\right)
$$

    Where;
        u = user's address
        x = start time
        y = end time
        A(u, x, y) = allocations of user u between time x and y
        B = balance of user (constant between time x and y - 1)
        AR = Allocation rate: allocation coeffiecient distributed per second
        T = total supply

Some modifications were made to ensure that the total allocations distributed between any given time is equal to (or very close to due to solidity rounding errors) to the sum of all hodlers allocation coefficient within that same period of time.

The Synthetix staking reward algorithm does support this as allocations are still distributed even when total supply is 0 which causes allocation coefficients to be distributed but to no address leading to the invariant (totalAllocations == sumAllocations) being false. More info [here]("https://0xmacro.com/blog/synthetix-staking-rewards-issue-inefficient-reward-distribution/"). To solve this. ERC20 Allocations introduces the concept of Sections which tracks the times when total supply was 0 and prevents distribution of allocations during these times.

Synthetix staking reward algorithm helps accurately calculating how much of a hodler an address was during the current timestamp. To make this more dynamic, its important that anyone be able to (and on chain) fetch this same data but for any given period of time in the past too. To do this, ERC20 Allocations uses the same pattern as Openzeppelin's ERC20 Snapshots to store the state of the variables used to calculate allocations of users and total allocations so that it can be queried by timestamp and used in different ways.

For utmost accuracy PRB-Math library is also used.
