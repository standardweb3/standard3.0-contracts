# Minigame

Inspired from Kucoin's [Futures brawl](https://www.kucoin.com/news/en-beginners-guide-on-how-to-get-started-quickly-in-futures-brawl) and [FOMO3D](https://cryptoslate.com/products/fomo3d/), this is a minigame to battle with other traders to brawl with prices combined with thrilling exit.

# How to play

1. Create a brawl with `create()` function. Choose asset pair to bet on long(price will go up), flat(price will stay), short(price will go down) from start price after set duration. For example, Bob creates a brawl when ETH/USDT rate is 3561, making someone to close the brawl after 5 mins. The minimum amount to set up the brawl is 0.01 ETH. 

2. Other users join the brawl to bet on the price. Within set time, in this case 5 mins, they can bet whether the price after 5 mins goes up(`long()`), stay still(`flat()`), or go down(`short()`) by depositing ETH. The group which bets at the right result gets all deposits from other decisions! The price is retrieved from the orderbook exchange contract. 

3. After time passes, everyone can end the brawl by calling `exit()` and winners are announced. Once winners are announced, winners gets all the money collected pro-rata to the deposit in their decision group. To be specific, when the brawl Bob created ended, ETH/USDT rate went up to 4000. Long betters won and long betters are now taking all deposits from short and flat betters. In total funds collected in the brawl, Bob deposited 20% of the long group. As Bob won, Bob takes 20% of the total funds collected from the brawl.

# Brawl Type

There are two types of Brawl being planned to support.

# Time brawl

Time brawl is a brawl where a user ends the brawl after set duration. The user who ends the brawl is incentivized with 1% of the total fund as fee.

# Fomo brawl

Fomo brawl is a brawl where a user ends the brawl being the last person set to end the game. 