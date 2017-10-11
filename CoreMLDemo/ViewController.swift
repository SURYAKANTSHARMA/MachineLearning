//
//  ViewController.swift
//  CoreMLDemo
//
//  Created by Suryakant Sharma on 10/10/2017.
//  Copyright © 2017 AppCoda. All rights reserved.
//

import UIKit
import CoreML
import Vision

enum DetectionType: Int {
   case inceptionv3
   case googleNetPlaces
}

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var classifier: UILabel!
    let vowels = "aioue"
    var model: Inceptionv3!
    var selectedDetectionType = DetectionType.inceptionv3
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

 
   override func viewWillAppear(_ animated: Bool) {
     super.viewWillAppear(animated)
     model = Inceptionv3()
   }
    @IBAction func camera(_ sender: Any) {
        
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        
        let cameraPicker = UIImagePickerController()
        cameraPicker.delegate = self
        cameraPicker.sourceType = .camera
        cameraPicker.allowsEditing = false
        
        present(cameraPicker, animated: true)
    }
    
    @IBAction func openLibrary(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
  
  @IBAction func segmentControllerPressed(_ sender: UISegmentedControl) {
    let selectedIndex = sender.selectedSegmentIndex
    selectedDetectionType = selectedIndex == 0 ? DetectionType.inceptionv3 : DetectionType.googleNetPlaces
    if selectedDetectionType == .googleNetPlaces {
    updateForGoogleNetPlaces(self.imageView.image)
    } else {
      guard let image = self.imageView.image else {
        return
      }
      updateForInception(image)
    }
  }
  func updateLabel() {
    
    
    
  }
  func updateForGoogleNetPlaces(_ image: UIImage?) {
    
    guard let model = try? VNCoreMLModel(for: GoogLeNetPlaces().model) else {
      fatalError("cann't load place from ML Model")
    }
    // Create a Vision request with completion handler
    let request = VNCoreMLRequest(model: model) { [weak self] request, error in
      guard let results = request.results as? [VNClassificationObservation],
        let topResult = results.first else {
          fatalError("unexpected result type from VNCoreMLRequest")
      }
      
      // Update UI on main queue
      let article = (self?.vowels.contains(topResult.identifier.first!))! ? "an" : "a"
      DispatchQueue.main.async { [weak self] in
        self?.classifier.text = "\(Int(topResult.confidence * 100))% it's \(article) \(topResult.identifier)"
      }
    }
    guard let image = image ?? self.imageView.image else {
      print("No image for processing...")
      return
    }
    if let ciImage = CIImage(image: image) {
    let handler = VNImageRequestHandler(ciImage: ciImage)
    DispatchQueue.global(qos: .userInteractive).async {
      do {
        try handler.perform([request])
      } catch {
        print(error)
      }
    }
    }
  }
}

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    picker.dismiss(animated: true)
    classifier.text = "Analyzing Image..."
    guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage else {
      return
    }
    if selectedDetectionType == .inceptionv3 {
     updateForInception(image)
    } else {
      updateForGoogleNetPlaces(image)
     }
  }
  
  func updateForInception(_ image: UIImage) {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: 299, height: 299), true, 2.0)
    image.draw(in: CGRect(x: 0, y: 0, width: 299, height: 299))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard (status == kCVReturnSuccess) else {
      return
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) //3
    
    context?.translateBy(x: 0, y: newImage.size.height)
    context?.scaleBy(x: 1.0, y: -1.0)
    
    UIGraphicsPushContext(context!)
    newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    imageView.image = newImage
    
    guard let prediction = try? model.prediction(image: pixelBuffer!) else {
      return
    }
    classifier.text = "I think this is a \(prediction.classLabel)."
    
  }
}
