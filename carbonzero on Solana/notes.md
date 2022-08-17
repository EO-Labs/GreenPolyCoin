---
---
## spl-token

```sh
# see also

michelc=Fg2RSRChcR5m1x8wTJWYbA1GD6kcKytcQM12kDNApf37
harrison=2m2tcHnwSfn1utWEtCJH25muqduwZ8Pm8WcSd52f14Eq
michel_sollet=14dNTfAR3MPU63CPbCjLx7tEQv4MnSpYP6s9VF3HG28R
qm=$(ipfs add -w -Q gbitcoin.json)

tokenkey=$(solana-keygen grind --ignore-case --starts-with PhX4:1 \
  --no-bip39-passphrase | tail -1 | cut -d' ' -f4)
tokenid=${tokenkey%.*}

spl-token create-token --with-memo $qm --decimals 0 $tokenkey
#tokenid=D17PtjrzxNANtGDacNMRNwxtBU59phYCQXLMJWL5K1DW
spl-token supply $tokenid
spl-token create-account $tokenid
# 27hTk2UA5H2qfqWfKtdebcZJAUnwQDqbSSJfjqPHWApW
spl-token balance $tokenid
spl-token mint $tokenid 1
spl-token supply $tokenid
spl-token balance $tokenid
spl-token accounts
```


## spl-memo

```sh
spl-token create-token --decimals 0
tokenid=JCr2wiyEHkegAtBEhmbKQBhwMqe749ngtEH1NSE3A82g


```
