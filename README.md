# Auction for randomizingly swap token
---

Features:

- Create auction
- Allow people to call pubish_lottery_result()
- Automatically send token to winner on withdrawal calls

## Setup:

** We should use docker for development **

- Download docker:

```
Please follow instruction on https://docs.docker.com/engine/install/ubuntu/
```

- Run ganache cli:

```
docker run -d -p 7777:8545 trufflesuite/ganache-cli
```

* Docker will automatically download ganache-cli image *

I love the port 7777, you could change this port in ``truffle-config.js``, but I think we should not do that.

