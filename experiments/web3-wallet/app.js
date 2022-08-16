
console.dir(window.web3)
web3.personal.sign(web3.fromUtf8("Hello from Toptal!"), web3.eth.coinbase, console.log);

async function main() {
const accounts = await ethereum.request({ method: 'eth_accounts' });

console.dir(accounts)


}

main();
