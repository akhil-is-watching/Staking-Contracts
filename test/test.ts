import { expect } from "chai"
import { ethers } from "hardhat"
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";


describe("Plexus Staking Contract", function() {

    async function initState() {
        let [ deployer ] = await ethers.getSigners()
        let Token = await ethers.getContractFactory("MERC20")
        let Pool = await ethers.getContractFactory("StakingPool")
        let Factory = await ethers.getContractFactory("PoolFactory")

        let token = await Token.deploy(deployer.address)
        let implementation = await Pool.deploy()
        let factory = await Factory.deploy(implementation.address, token.address)
        await factory.deployed()

        await token.connect(deployer).approve(factory.address, ethers.utils.parseEther('10000000000000.0'))

        return { deployer, token, implementation, factory, Pool }
    }

    describe("Deployment", function() {
        it("Should deploy correctly", async function() {
            let { deployer, token, implementation, factory, Pool } = await loadFixture(initState)
            let salt = "0x626862686a62686a62686a62686a000000000000000000000000000000000000"
            let address = await factory.predictAddress(salt)
            await factory.createPool(600, 100, salt)

            let pool = await ethers.getContractAt("StakingPool", address)

            expect(await pool.rewardBalanceAvailable()).not.to.reverted;
        })
    })

    describe("Factory", function() {
        it("Should create pools correctly", async function() {            
            let { deployer, token, implementation, factory, Pool } = await loadFixture(initState)
            let salt = "0x626862686a62686a62686a62686a000000000000000000000000000000000000"
            let address = await factory.predictAddress(salt)
            await factory.createPool(600, 100, salt)

            let pool = await ethers.getContractAt("StakingPool", address)

            expect(await pool.rewardBalanceAvailable()).not.to.reverted;
        })

        it("Should deposit rewards correctly", async function() {
            let { deployer, token, implementation, factory, Pool } = await loadFixture(initState)
            let salt = ["0x7465737431000000000000000000000000000000000000000000000000000000", "0x7465737432000000000000000000000000000000000000000000000000000000", "0x7465737433000000000000000000000000000000000000000000000000000000"]
            let pool1address = await factory.predictAddress(salt[0])
            let pool2address = await factory.predictAddress(salt[1])
            let pool3address = await factory.predictAddress(salt[2])

            await factory.createPool(600, 100, salt[0])
            await factory.createPool(800, 150, salt[1])
            await factory.createPool(1200, 200, salt[2])

            let pool1 = await Pool.attach(pool1address)
            let pool2 = await Pool.attach(pool1address)
            let pool3 = await Pool.attach(pool1address)

            expect(await factory.depositReward(ethers.utils.parseEther('100.0'), [pool1address, pool2address, pool3address], [2000, 3000, 5000])).not.to.reverted;
            expect(await factory.poolRewardBalance(pool1address)).to.equal(ethers.utils.parseEther('20.0'));
            expect(await factory.poolRewardBalance(pool2address)).to.equal(ethers.utils.parseEther('30.0'));
            expect(await factory.poolRewardBalance(pool3address)).to.equal(ethers.utils.parseEther('50.0'));
        })
    })


    describe("Staking Pool", function() {
        it("Should deposit correctly", async function(){
            let { deployer, token, implementation, factory, Pool } = await loadFixture(initState)
            let salt = ["0x7465737431000000000000000000000000000000000000000000000000000000", "0x7465737432000000000000000000000000000000000000000000000000000000", "0x7465737433000000000000000000000000000000000000000000000000000000"]
            let pooladdress = await factory.predictAddress(salt[0])

            await factory.createPool(600, 600, salt[0])
            let pool = await Pool.attach(pooladdress)

            await token.approve(pool.address, ethers.utils.parseEther('10.0'))
            expect(await pool.deposit(ethers.utils.parseEther('5.0'))).not.to.reverted;
            let stake = await pool.getStake(deployer.address)
            expect(stake.amount).to.equal(ethers.utils.parseEther('5.0'))
            expect(stake.expectedReward).to.equal(ethers.utils.parseEther('5.0').mul("600").div("10000"))
        })

        it("Should accept concurrent deposits correctly", async function() {
            let { deployer, token, implementation, factory, Pool } = await loadFixture(initState)
            let salt = ["0x7465737431000000000000000000000000000000000000000000000000000000", "0x7465737432000000000000000000000000000000000000000000000000000000", "0x7465737433000000000000000000000000000000000000000000000000000000"]
            let pooladdress = await factory.predictAddress(salt[0])

            await factory.createPool(600, 600, salt[0])
            let pool = await Pool.attach(pooladdress)

            await token.approve(pool.address, ethers.utils.parseEther('10.0'))
            await pool.deposit(ethers.utils.parseEther('5.0'))
            let stakeBefore = await pool.getStake(deployer.address)
            expect(stakeBefore.accumulatedReward).to.equal(0)
            await time.increase(300);
            expect(await pool.deposit(ethers.utils.parseEther('5.0'))).not.to.reverted;
            let stake = await pool.getStake(deployer.address)
            expect(stake.amount).to.equal(ethers.utils.parseEther('10.0'))
            expect(stake.accumulatedReward).to.equal(ethers.utils.parseEther('5.0').mul("301").mul("600").div("10000").div("600"))
            expect(stake.expectedReward).to.equal(ethers.utils.parseEther('10.0').mul("600").div("10000"))
        })

        it("Should withdraw correctly", async function(){
            let { deployer, token, implementation, factory, Pool } = await loadFixture(initState)
            let salt = ["0x7465737431000000000000000000000000000000000000000000000000000000", "0x7465737432000000000000000000000000000000000000000000000000000000", "0x7465737433000000000000000000000000000000000000000000000000000000"]
            let pooladdress = await factory.predictAddress(salt[0])

            await factory.createPool(600, 600, salt[0])
            let pool = await Pool.attach(pooladdress)

            await token.approve(pool.address, ethers.utils.parseEther('10.0'))
            await pool.deposit(ethers.utils.parseEther('5.0'))
            await time.increase(500);
            await pool.deposit(ethers.utils.parseEther('5.0'))
            await time.increase(600);
            expect(await pool.withdraw()).to.not.reverted;
            let stake = await pool.getStake(deployer.address)
            expect(stake.amount).to.equal(0)
        })

        it("Should claim rewards correctly", async function(){
            let { deployer, token, implementation, factory, Pool } = await loadFixture(initState)
            let salt = ["0x7465737431000000000000000000000000000000000000000000000000000000", "0x7465737432000000000000000000000000000000000000000000000000000000", "0x7465737433000000000000000000000000000000000000000000000000000000"]
            let pooladdress = await factory.predictAddress(salt[0])

            await factory.createPool(600, 600, salt[0])
            let pool = await Pool.attach(pooladdress)

            await token.approve(pool.address, ethers.utils.parseEther('10.0'))
            await pool.deposit(ethers.utils.parseEther('5.0'))
            await time.increase(500);
            await pool.deposit(ethers.utils.parseEther('5.0'))
            await time.increase(600);
            await pool.withdraw()
            expect(pool.claimReward()).to.be.revertedWith("ERR: INSUFFICIENT REWARD BALANCE")
            expect(await factory.depositReward(ethers.utils.parseEther("20"), [pool.address], [10000])).not.to.reverted;
            expect(await pool.claimReward()).not.to.reverted;
            let stake = await pool.getStake(deployer.address)
            expect(stake.expectedReward).to.equal(0)
            expect(stake.accumulatedReward).to.equal(0)
        })
    })
})