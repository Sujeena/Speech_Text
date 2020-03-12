//
//  ViewController.swift
//  SpeechToText
//
//  Created by Sujeena on 3/11/20.
//  Copyright © 2020 Sujeena. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate, UITableViewDataSource {
    
    var loc = 0
    var len = 0
    var keywordList:[String] = []
    
    @IBOutlet weak var tableVw: UITableView!
    
    @IBOutlet weak var recordingButton: UIButton!
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var addKeywordButton: UIButton!
    @IBOutlet weak var displayKeyword: UITextView!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK - ViewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableVw.isHidden = true
        recordingButton.isHidden = true

        self.tableVw.dataSource=self
        
        self.recordingButton.isEnabled = false
        self.speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.recordingButton.isEnabled = isButtonEnabled
            }
        }
    }
    
    // MARK: - Tableview DataSource Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if keywordList.count > 0 {
            return keywordList.count
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableVw.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TableViewCell
        if keywordList.count > 0 {
            cell.title.text = keywordList[indexPath.row]
            recordingButton.isHidden = false
        }
        return cell
    }
    
    // MARK: - Button Actions
    
    @IBAction func startButtonClicked(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordingButton.isEnabled = false
            recordingButton.setTitle("Start Recording", for: .normal)
        } else {
            startRecording()
            recordingButton.setTitle("Stop Recording", for: .normal)
        }
    }
    
    func startRecording() {
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                self.textView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
                self.highlightText(textView: self.textView)
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordingButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        textView.text = "Say something, I'm listening!"
        textView.textColor = UIColor.black
    }
    
    @IBAction func addKeywordClicked(_ sender: Any) {
        tableVw.isHidden = false
        self.tableVw.dataSource = self
        var addTextField: UITextField?
        let alertController = UIAlertController(
            title: "Add Keyword",
            message: "Please enter your keyword",
            preferredStyle: .alert)
        let addAction = UIAlertAction(
        title: "Add", style: .default) {
            (action) -> Void in
            if let keyword = addTextField?.text {
                self.keywordList.append(keyword)
                self.tableVw.reloadData()
            } else {
                print("No Keyword entered")
            }
        }
        alertController.addTextField {
            (txtName) -> Void in
            addTextField = txtName
            addTextField!.placeholder = "Enter Keyword"
        }
        alertController.addAction(addAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func highlightText(textView: UITextView) -> NSMutableAttributedString{
        let myText = textView.text
        let string:NSMutableAttributedString = NSMutableAttributedString(string: myText!)
        let arrayOfWords = myText!.components(separatedBy: " ")
        var currentLocation = 0
        var currentLength = 0
        var arrayOfRanges = [NSRange]()
        
        for word in arrayOfWords {
            currentLength = word.count
            arrayOfRanges.append(NSRange(location: currentLocation, length: currentLength))
            currentLocation += currentLength + 1
            for rng in arrayOfRanges {
                loc = rng.location
                len = rng.length
            }
            if keywordList.contains(word.lowercased()) {
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.red, range: NSRange(location: loc, length: len))
            }
        }
        textView.attributedText = string
        return string
    }
    
    // MARK: - SpeechRecognizer Delegate Method
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordingButton.isEnabled = true
        } else {
            recordingButton.isEnabled = false
        }
    }
}

