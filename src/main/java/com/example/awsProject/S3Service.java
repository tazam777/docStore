package com.example.awsProject;

// AWS S3 SDK + Spring imports] 
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.S3Object;


import java.io.IOException;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class S3Service {
    private final S3Client s3Client = S3Client.builder().region(Region.US_EAST_2).build();
    private final String bucket = "pdf.upload-1"; 

    public String uploadFile(MultipartFile file) throws IOException {
        String key = file.getOriginalFilename(); 
        s3Client.putObject(PutObjectRequest.builder().bucket(bucket).key(key).build(),RequestBody.fromBytes(file.getBytes()));
        // Return S3 URL for your object
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }



public List<String> getFile() {
    ListObjectsV2Request request = ListObjectsV2Request.builder().bucket(bucket).build();
    ListObjectsV2Response response = s3Client.listObjectsV2(request);

    return response.contents().stream() .map(S3Object::key).collect(Collectors.toList());
}


}
