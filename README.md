# **ERC20 Merit**

### - **ERC20 token utilizing its novel "Time Weighted Aggregated Merit (TWAM) Oracle"**

According to the oxford dictionary, Merit can be defined as any of the following and more

- Noun: the quality of being particularly good or worthy, especially so as to deserve praise or reward.
- Verb: deserve or be worthy of (reward, punishment, or attention).

The ERC20 TWAM extension distributes `Merit Allocations` from a fixed amount of merit allocation that's emitted per second to holders per second and based on the percentage of the total supply each user owns at that given second for that token. It aggregates this merit allocation every second to create a time weighted, unbiased and harder to manipulate allocation for users based on their loyalty to holding the token over time.

The token contract also takes a snapshot of the Merit state of the contract and all users whenever their balances are updated. This allows any other contract on-chain or backend/frontend off-chain to query and use the Merit allocation of any address within any specified period of time to issue priviledges to them like voting power, rewards, discounts, etc.

This system is even more difficult to manipulate as purchasing a large majority of that token's total supply for a short period of time to get more priviledges won't pay off as the bad actor can only earn a fixed amount of this Merit allocation (merit emission rate _ seconds held _ percentage ownership while hodling), and in most scenarios won't have higher aggregated allocation than long time hodlers. This means that the merit allocation of each token holder is proportionate to their stake in the project over time, this gives more power to addresses with more risk/skin in the game i.e invested significantly into the token for a longer period of time.

### **A contract can get the allocation of an address between timestamps 100 and 200 by;**

- Get the total allocations distributed between time 100 and 200 by calling `totalAllocationsBetween(tokenAddress, 100, 200)`. Under the hood this gets the total allocations distributed as at timestamps 100 and 200 and subtracts the latter from the former.
- Get the allocations earned by the address in question between time 100 and 200 by calling `allocatedBetween(tokenAddress, userAddress, 100, 200)`. Under the hood this gets the allocations earned by the user as at timestamps 100 and 200 and subtracts the latter from the former.
- Both data can be queried individually and used as a fraction for calculating anything. DAO voting rights, Airdrop distribution, hold to earn reward distribution.
- The allocations of a user or total allocation distributed at a given time can be queried individually too not just between ranges which can be important for other use cases.

There are several potential use cases for ERC20 Allocations. For example, this data can be used for fair governance voting by allowing token holders to vote in proportion to their loyalty and stake in the project over a specified period of time, rather than randomly or based on the amount of tokens held at a single timestamp. It can also be used for airdrop distribution based on the loyalty of another token's holders. Additionally, this data can be used for hold-to-earn reward distribution without requiring users to stake their tokens, which reduces the risks associated with staking if the staking contract is compromised.

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
