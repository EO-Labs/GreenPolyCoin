
if (false) {
  console.dir(window.web3)
  web3.personal.sign(web3.fromUtf8(`Hello from ${location.hostname}!`), web3.eth.coinbase, console.log);
}

!(async function main() { // assumed "ether.js" loaded
const accounts = await ethereum.request({ method: 'eth_accounts' });

console.dir(accounts)

  const api_url = 'http://127.0.0.1:5000/api/v0';
  const endpoints = {
    nonce: '/get/nonce',
    login: '/login',
    auth: '/auth'
  };

 async function web3Login() {
        if (!window.ethereum) {
            alert('MetaMask not detected. Please install MetaMask first.');
            return;
        }
    }


  document.getElementById('login').addEventListener('click',web3Login,false);

  async function web3Login(ev) {
    let resp = await fetch(endpoints.nonce)
    console.log('resp:', resp);
  }


})();
