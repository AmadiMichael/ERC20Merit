# **ERC20 ALLOCATIONS**

ERC20 Allocations is an extension of the widely used ERC20 token standard that automatically tracks and stores information about the most loyal token holders. Specifically, this extension introduces a new concept called the "allocation coefficient", which is distributed to token holders on a per-second basis based on the percentage of the total supply each user owns at that given second. This ensures that the allocation coefficient of each token holder is proportionate to their stake in the project and over time. Removing addresses with large reserves from atomically taking advantage of perks of holding a token.

This data is stored permanently on the blockchain and can be queried on-chain to determine the top token holders within a given period of time. To do this, one needs to retrieve the total allocation distributed as of the start and end of the given period, as well as the allocation coefficients of each token holder at those times. With this information, one can calculate the allocations for each token holder during the given period.

- Get the total allocations distributed as at timestamp 100 and 200 each. We will call them `totalAllocation(100)` and `totalAllocation(200)` respectively.
- Get the allocations of `address(0xabcd)` as at timestamp 100 and 200 each. We will call them `allocations(address(0xabcd), 100)` and `allocations(address(0xabcd), 200)` respectively.
- Allocations of address(0xabcd) between 100 and 200 is `allocations(address(0xabcd), 200) - allocations(address(0xabcd), 100)`
- The total allocations distributed to holders of that token between time 100 and 200 is `totalAllocation(200) - totalAllocation(100)`
- Both data can be queried individually and used as a fraction for calculating anything. DAO voting rights, Airdrop distribution, hold to earn reward distribution.

There are several potential use cases for ERC20 Allocations. For example, this data can be used for fair governance voting by allowing token holders to vote in proportion to their loyalty and stake in the project over time , rather than randomly or based on the amount of tokens held at a single timestamp. It can also be used for airdrop distribution based on the loyalty of another token's holders. Additionally, this data can be used for hold-to-earn reward distribution without requiring users to stake their tokens ("Liquid staking" if you will), which reduces the risks associated with staking if the staking contract is compromised.

Overall, ERC20 Allocations is a powerful extension of the ERC20 token standard that provides permanent, on-chain data about token holder loyalty and stake. This data has numerous potential use cases and can provide a more fair, transparent, and secure way of distributing rewards and making governance decisions within blockchain projects.

# **How it works**

For efficiently calculating the "allocation coeffiecient" of any given address, ERC20 Allocations use a similar model as Synthetix's staking rewards contract

$$
A(u, x, y) = B \left( \sum_{t = 0}^{y - 1} \frac {AR}{T} - \sum_{t = 0}^{x - 1} \frac {AR}{T}
\right)
$$

    Where;
        u = user's address
        x = start time
        y = end time
        B = balance of user (constant between time x and y - 1)
        AR = Allocation rate: allocation coeffiecient distributed per second
        T = total supply

Some modifications were made to ensure that the total allocations distributed between any given time is equal to (or very close to due to solidity rounding errors) to the sum of all hodlers allocation coefficient within that same period of time.

The Synthetix staking reward algorithm does support this as allocations are still distributed even when total supply is 0 which causes allocation coefficients to be distributed but to no address leading to the invariant (totalAllocations == sumAllocations) being false. More info [here]("https://0xmacro.com/blog/synthetix-staking-rewards-issue-inefficient-reward-distribution/"). To solve this. ERC20 Allocations introduces the concept of Sections which tracks the times when total supply was 0 and prevents distribution of allocations during these times.

Synthetix staking reward algorithm helps accurately knowing how much of a hodler an address was during the current timestamp. To make this more dynamic, we want anyone to be able to (on chain) fetch this same data but for any given period of time in the past or present. To do this, ERC20 Allocations uses the same pattern as Openzeppelin's ERC20 Snapshots to store the state of the variables used to calculate allocations of users and total allocations so that it can be queried by timestamp and used in different ways.

For utmost accuracy PRB-Math library is also used.
