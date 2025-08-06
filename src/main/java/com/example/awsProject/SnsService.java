
package com.example.awsProject;

import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

public class SnsService {

    private final SnsClient snsClient = SnsClient.builder()
            .region(Region.US_EAST_2)
            .build();

    public static final String topicArn = "arn:aws:sns:us-east-2:033376538641:pdfUploadNotify";

    public void notify(String fileName) {
        String message = "File uploaded is " + fileName;

        PublishRequest request = PublishRequest.builder()
                .topicArn(topicArn)
                .subject("New File Upload")
                .message(message)
                .build();

        snsClient.publish(request);
        System.out.println("Email sent via SNS for file: " + fileName);
    }
}
