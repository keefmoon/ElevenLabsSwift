import AVFoundation

extension ElevenLabsSDK {
    
    public final class MacInput: Input {
        
        private let audioEngine = AVAudioEngine()
        private let sampleRate: Double
        private var audioConverter: AVAudioConverter?
        private var recordCallback: ((AVAudioPCMBuffer, Float) -> Void)?
        public var isRecording: Bool = false
        
        init(sampleRate: Double) {
            self.sampleRate = sampleRate
        }
        
        public static func create(sampleRate: Double) async throws -> MacInput {
            return MacInput(sampleRate: sampleRate)
        }
        
        public func setRecordCallback(_ callback: @escaping (AVAudioPCMBuffer, Float) -> Void) {
            
            let inputNode = audioEngine.inputNode
            let hardwareFormat = inputNode.outputFormat(forBus: 0) // Use hardware's native format

            // Set up the audio converter to convert from the hardware sample rate to 24,000 Hz
            let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true)
            audioConverter = AVAudioConverter(from: hardwareFormat, to: desiredFormat!)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { (buffer, time) in
                self.convertAndProcessAudioBuffer(buffer)
            }

            audioEngine.prepare()
            recordCallback = callback
            isRecording = true
            try? audioEngine.start()
        }
        
        public func close() {
            isRecording = false
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        private func convertAndProcessAudioBuffer(_ buffer: AVAudioPCMBuffer) {
            recordCallback?(buffer, calculateRMS(from: buffer))
        }
        
        private func calculateRMS(from buffer: AVAudioPCMBuffer) -> Float {
            // Ensure we have valid audio data
            guard let channelData = buffer.floatChannelData else {
                return 0.0
            }
            
            // Get the number of frames and channels
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            
            // Variables to accumulate sum of squares and total sample count
            var totalSquaredSum: Float = 0.0
            var totalSampleCount: Int = 0
            
            // Iterate through each channel
            for channel in 0..<channelCount {
                let channelSamples = channelData[channel]
                
                // Sum the squares of the samples
                var squaredSum: Float = 0.0
                for frame in 0..<frameCount {
                    let sample = channelSamples[frame]
                    squaredSum += sample * sample
                }
                
                totalSquaredSum += squaredSum
                totalSampleCount += frameCount
            }
            
            // Calculate RMS
            let rms = sqrt(totalSquaredSum / Float(totalSampleCount))
            return rms
        }
    }
}
