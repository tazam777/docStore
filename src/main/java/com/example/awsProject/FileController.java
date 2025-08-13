package com.example.awsProject;

import java.util.ArrayList;

import org.apache.commons.lang3.StringUtils;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
public class FileController {

    private final S3Service s3Service;
    private final SnsService snsService;

    public FileController(S3Service s3Service, SnsService snsService) {
        this.s3Service = s3Service;
        this.snsService = snsService;
    }

    @PostMapping("/upload")
    public ResponseEntity<String> uploadFile(@RequestParam("file") MultipartFile file) {
        try {
            String fileName = file.getOriginalFilename();
            String s3Url = s3Service.uploadFile(file);

            snsService.notify(fileName);

            return ResponseEntity.ok("File uploaded successfully: " + s3Url);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(500).body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/get")
    public ResponseEntity<String> getFile() {
        try {
          String SucessResponse="Success"+ "\n"+ "Files uploaded are : "+ StringUtils.join(s3Service.getFile(), ", ");
        return ResponseEntity.ok(SucessResponse);
        } catch (Exception e) {
            e.printStackTrace();
        return ResponseEntity.status(500).body("Error: " + e.getMessage());
        }
    }
}
