package com.escrow.mock.listener;

import com.escrow.mock.model.BuildPayload;
import com.escrow.mock.service.GitLabService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rabbitmq.client.Channel;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.amqp.rabbit.listener.RabbitListenerEndpointRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class QueueListener {

    private final GitLabService gitLabService;
    private final RabbitListenerEndpointRegistry registry;
    private final ObjectMapper objectMapper;

    @Value("${escrow.queueName}")
    private String queueName;

    // Use a fixed id for the listener to easily start/stop it
    public static final String LISTENER_ID = "escrowListener";

    @RabbitListener(id = LISTENER_ID, queues = "${escrow.queueName}", ackMode = "MANUAL")
    public void receiveMessage(String messageJson, Channel channel, @Header(AmqpHeaders.DELIVERY_TAG) long tag) {
        log.info("Received message from queue: {}", queueName);
        try {
            BuildPayload payload = objectMapper.readValue(messageJson, BuildPayload.class);
            log.info("Processing payload for branch {} and commit {}", payload.getBranch(), payload.getCommitHash());
            
            // Here the application should theoretically clone the repo and push it to escrow before triggering pipeline.
            // For the sake of this mock phase, we assume the codebase is mirroring in Escrow,
            // or that the pipeline itself handles the alignment step.
            gitLabService.triggerProviderPipelineAndWait(payload);
            log.info("Successfully processed message and triggered pipeline.");
            
            // Send ACK manually
            channel.basicAck(tag, false);
        } catch (Exception e) {
            log.error("Error processing message or triggering pipeline: {}", e.getMessage(), e);
            haltQueue();
            
            try {
                // Reject message and put it back in the queue
                channel.basicNack(tag, false, true);
            } catch (Exception ex) {
                log.error("Failed to NACK message: {}", ex.getMessage());
            }
            
            // By stopping the listener, it won't consume the next messages until manual resume.
            throw new RuntimeException("Failed to process message, queue halted.", e);
        }
    }

    private void haltQueue() {
        log.warn("HALTING QUEUE LISTENER due to error. Manual resume required.");
        registry.getListenerContainer(LISTENER_ID).stop();
    }
}
