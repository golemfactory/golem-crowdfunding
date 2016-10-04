# golem-crowdfunding

Deployment process:

1. Owner account is created (may be a multisig wallet address)
2. Founder wallet is created (must be a multisig wallet, may be the owner address)
3. GolemCrowdfunding contract is deployed by the owner
  a) Hardcode founder wallet address in the contract
  b) Deploy the contract (with valid start and end blocks - see the constructor)
4. GolemNetworkToken is deployed
  a) Hardcode GolemCrowdfunding into GolemNetworkToken
  b) Deploy the contract
5. Owner calls GolemNetworkToken.initialize(address of GolemNetworkToken contract)
6. During the crowdsale the default function is called to fund Golem and issue corresponding GNT for the funder
7. After the crowdsale the default function can be called by any funder to reclaim sent funds (in case min cap was not reched)
8. After the crowdsale owner (only if the min cap was reached)
  a) calls GolemCrowdfunding.transferEtherToFounder to transfer ETH to funder address
  b) calls GolemCrowdfunding.issueFounderTokens to issue predefined percent (18%) of funder tokens

Remarks:

GolemNetworkToken is not locked at any time which means that GNT owners can transfer the token at any time during the crowdsale. ETH transfers are tracked by the crowdfunding contract so that the exact amount sent to the contract 
can be returned in case the min cap is not reached.
