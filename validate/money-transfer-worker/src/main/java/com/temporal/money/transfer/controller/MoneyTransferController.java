package com.temporal.money.transfer.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.temporal.money.transfer.model.CoreTransactionDetails;
import com.temporal.money.transfer.model.Message;
import com.temporal.money.transfer.util.Shared;
import com.temporal.money.transfer.workflow.MoneyTransferWorkflow;

import io.temporal.client.WorkflowClient;
import io.temporal.client.WorkflowOptions;

@RestController
public class MoneyTransferController {

	@Autowired
	WorkflowClient client;

	@PostMapping(value = "/transfer", produces = MediaType.APPLICATION_JSON_VALUE)
	public Message startSubscription(@RequestBody CoreTransactionDetails data) {

		WorkflowOptions options = WorkflowOptions.newBuilder().setTaskQueue(Shared.MONEY_TRANSFER_TASK_QUEUE)
				.setWorkflowId("money-transfer").build();
		MoneyTransferWorkflow workflow = client.newWorkflowStub(MoneyTransferWorkflow.class, options);
		WorkflowClient.start(workflow::transfer, data);
		
		return new Message("Resource Created Successfully");

	}

}
