package com.example.awsProject;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;
import software.amazon.awssdk.services.sns.model.PublishResponse;

@Service
public class SnsService {

    private final SnsClient snsClient;
    private final String topicArn;

    public SnsService(
            @Value("${app.sns.topic-arn}") String topicArn,
            @Value("${AWS_REGION:us-east-2}") String region // falls back to us-east-2
    ) {
        this.snsClient = SnsClient.builder().region(Region.of(region)).build();
        this.topicArn = topicArn;
    }

    public void notify(String fileName) {
        String message = "File uploaded is " + fileName;

        PublishRequest req = PublishRequest.builder().topicArn(topicArn).subject("New File Upload of name " +fileName).message(message).build();
        PublishResponse res = snsClient.publish(req);
        System.out.println("SNS published. MessageId=" + res.messageId());
    }
}
