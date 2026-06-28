// @@@SNIPSTART money-transfer-java-activity-implementation
package com.temporal.money.transfer.activity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import io.temporal.activity.Activity;
import io.temporal.spring.boot.ActivityImpl;

@Component
@ActivityImpl(workers = "money-transfer")
public class AccountActivityImpl implements AccountActivity {
	
	private static Logger log = LoggerFactory.getLogger(AccountActivityImpl.class);
    // Mock up the withdrawal of an amount of money from the source account
    @Override
    public void withdraw(String accountId, String referenceId, int amount) {
        log.info("Withdrawing " + amount + " from account " + accountId + " ReferenceId: " + referenceId);
        System.out.flush();
    }

    // Mock up the deposit of an amount of money from the destination account
    @Override
    public void deposit(String accountId, String referenceId, int amount) {
        boolean activityShouldSucceed = true;

        if (!activityShouldSucceed) {
        	log.info("Deposit failed");
            System.out.flush();
            throw Activity.wrap(new RuntimeException("Simulated Activity error during deposit of funds"));
        }

        log.info("Depositing "+ amount + " into account " + accountId + " ReferenceId: " + referenceId);
        System.out.flush();
    }

    // Mock up a compensation refund to the source account
    @Override
    public void refund(String accountId, String referenceId, int amount) {
        boolean activityShouldSucceed = true;

        if (!activityShouldSucceed) {
        	log.info("Refund failed");
            System.out.flush();
            throw Activity.wrap(new RuntimeException("Simulated Activity error during refund to source account"));
        }

        log.info("Refunding "+ amount + " to account "+ accountId + " ReferenceId: " + referenceId);
        System.out.flush();
   }
}
// @@@SNIPEND
