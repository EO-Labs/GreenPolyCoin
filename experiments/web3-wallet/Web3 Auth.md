### Web3 authentication

Login sequence

```mermaid
sequenceDiagram
      
FE->>BE: Log me in using Metamask.

    BE-->>FE: Please sign this challenge.
    MM->>FE: select a wallet
    FE->>MM: Please sign this with my "active wallet".
    MM-->>FE: Here is the signature token.
FE->>BE: Log me in using the signature token.
BE-->>FE: You are logged in using the signature token.
```

> Note:  no web3 available on mobile, need develop own wallet or use the [app version][mm] of metamask

[mm]: https://consensys.net/blog/news/metamask-mobile-now-available-on-android-and-ios/

![[2022-08-16 09.49 web3-Auth]]