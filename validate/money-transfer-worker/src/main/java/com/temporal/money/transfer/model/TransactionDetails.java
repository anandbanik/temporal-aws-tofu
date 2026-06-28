// @@@SNIPSTART money-transfer-java-transaction-details
package com.temporal.money.transfer.model;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

@JsonDeserialize(as = CoreTransactionDetails.class)
public interface TransactionDetails {
    String getSourceAccountId();
    String getDestinationAccountId();
    String getTransactionReferenceId();
    int getAmountToTransfer();
}
// @@@SNIPEND

