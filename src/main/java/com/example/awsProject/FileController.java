


package com.example.awsProject;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import software.amazon.awssdk.services.s3.model.S3Object;


@RestController

public class FileController {
    @Autowired
    private S3Service s3Service;

    @PostMapping("/upload")
    public ResponseEntity<String> uploadFile(@RequestParam("file") MultipartFile file) {
        try {
            String s3Url = s3Service.uploadFile(file);
            return ResponseEntity.ok("File uploaded successfully: " + s3Url);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(500).body("Error: " + e.getMessage());
        }
    }


    @PostMapping("/get")
    public ResponseEntity<String>getFile() {
    try {

        

        System.out.println(s3Service.getFile());
        return ResponseEntity.status(200).body("Sucess");
    } catch (Exception e) {
        e.printStackTrace();
        return ResponseEntity.status(500).body("Error: " + e.getMessage());
    }
}



 
}

    
