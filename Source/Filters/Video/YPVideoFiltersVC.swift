//
//  VideoFiltersVC.swift
//  YPImagePicker
//
//  Created by Nik Kov || nik-kov.com on 18.04.2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import Photos
import PryntTrimmerView
import AVFoundation
import Stevia
public class YPVideoFiltersVC: UIViewController, IsMediaFilterVC ,UIGestureRecognizerDelegate{
    
    @IBOutlet weak var trimBottomItem: YPMenuItem!
    @IBOutlet weak var coverBottomItem: YPMenuItem!
    
    
    fileprivate let filters: [YPFilter] = YPConfig.filters
    
    fileprivate var selectedFilter: YPFilter?
    
    fileprivate var filteredThumbnailImagesArray: [UIImage] = []
    fileprivate var thumbnailImageForFiltering: CIImage? // Small image for creating filters thumbnails
    fileprivate var currentlySelectedImageThumbnail: UIImage? // Used for comparing with original image when tapped

    
//    @IBOutlet var v: YPFiltersView!
  
    @IBOutlet var collectionViewContainer: UIView!
    @IBOutlet var collectionView: UICollectionView!
    
    @IBOutlet var filtersLoader: UIActivityIndicatorView!
    
    @IBOutlet weak var videoView: YPVideoView!
    @IBOutlet weak var trimmerView: TrimmerView!
    
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var coverThumbSelectorView: ThumbSelectorView!

    public var inputVideo: YPMediaVideo!
    public var inputAsset: AVAsset { return AVAsset(url: inputVideo.url) }
    
    private var playbackTimeCheckerTimer: Timer?
    private var imageGenerator: AVAssetImageGenerator?
    private var isFromSelectionVC = false
    
    var didSave: ((YPMediaItem) -> Void)?
    var didCancel: (() -> Void)?

    /// Designated initializer
    public class func initWith(video: YPMediaVideo,
                               isFromSelectionVC: Bool) -> YPVideoFiltersVC {
        let vc = YPVideoFiltersVC(nibName: "YPVideoFiltersVC", bundle: Bundle(for: YPVideoFiltersVC.self))
        vc.inputVideo = video
        vc.isFromSelectionVC = isFromSelectionVC
        
        return vc
    }
    
    // MARK: - Live cycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        
    
        
//        self.v = YPFiltersView()
//          v.imageView.image = self.inputVideo.thumbnail
       
        
//        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout())
        collectionView.collectionViewLayout = layout()
        filtersLoader.style = .gray
//        filtersLoader = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        filtersLoader.hidesWhenStopped = true
        filtersLoader.startAnimating()
        filtersLoader.color = YPConfig.colors.tintColor
         collectionView.backgroundColor = UIColor.white
//        collectionViewContainer.sv(
//            filtersLoader,
//            collectionView
//        )
        
//        let isIphone4 = UIScreen.main.bounds.height == 480
//        let sideMargin: CGFloat = isIphone4 ? 0 : 0
//
//        |-sideMargin-collectionView.top(0)-sideMargin-|
//         |-sideMargin-collectionView.bottom(0)-sideMargin-|
//         |-sideMargin-collectionView.left(0)-sideMargin-|
//        |-sideMargin-collectionView.right(0)-sideMargin-|
//        collectionViewContainer.bottom(0)
//        filtersLoader.centerInContainer()
//
         thumbnailImageForFiltering = thumbFromImage(self.inputVideo.thumbnail)
        DispatchQueue.global().async {
            self.filteredThumbnailImagesArray = self.filters.map { filter -> UIImage in
                if let applier = filter.applier,
                    let thumbnailImage = self.thumbnailImageForFiltering,
                    let outputImage = applier(thumbnailImage) {
                    return outputImage.toUIImage()
                } else {
                    return self.inputVideo.thumbnail
                }
            }
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.collectionView.selectItem(at: IndexPath(row: 0, section: 0),
                                                 animated: false,
                                                 scrollPosition: UICollectionView.ScrollPosition.bottom)
                self.filtersLoader.stopAnimating()
            }
        }
        
        // Setup of Collection View
        self.collectionView.register(YPFilterCollectionViewCell.self, forCellWithReuseIdentifier: "FilterCell")
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
      
//        self.collectionView.collectionViewLayout
        // Touch preview to see original image.
        let touchDownGR = UILongPressGestureRecognizer(target: self,
                                                       action: #selector(handleTouchDown))
        touchDownGR.minimumPressDuration = 0
        touchDownGR.delegate = self
//        v.imageView.addGestureRecognizer(touchDownGR)
//        v.imageView.isUserInteractionEnabled = true
        
        trimmerView.mainColor = YPConfig.colors.trimmerMainColor
        trimmerView.handleColor = YPConfig.colors.trimmerHandleColor
        trimmerView.positionBarColor = YPConfig.colors.positionLineColor
        trimmerView.maxDuration = YPConfig.video.trimmerMaxDuration
        trimmerView.minDuration = YPConfig.video.trimmerMinDuration
        
        coverThumbSelectorView.thumbBorderColor = YPConfig.colors.coverSelectorBorderColor
        
        trimBottomItem.textLabel.text = YPConfig.wordings.trim
        coverBottomItem.textLabel.text = YPConfig.wordings.cover

        trimBottomItem.button.addTarget(self, action: #selector(selectTrim), for: .touchUpInside)
        coverBottomItem.button.addTarget(self, action: #selector(selectCover), for: .touchUpInside)
        
        // Remove the default and add a notification to repeat playback from the start
        videoView.removeReachEndObserver()
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(itemDidFinishPlaying(_:)),
                         name: .AVPlayerItemDidPlayToEndTime,
                         object: nil)
        
        // Set initial video cover
        imageGenerator = AVAssetImageGenerator(asset: self.inputAsset)
        imageGenerator?.appliesPreferredTrackTransform = true
        didChangeThumbPosition(CMTime(seconds: 1, preferredTimescale: 1))
        
        // Navigation bar setup
        title = YPConfig.wordings.trim
        if isFromSelectionVC {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: YPConfig.wordings.cancel,
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(cancel))
        }
        setupRightBarButtonItem()
    }
    // MARK: - #########

    func layout() -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        
        return layout
    }
    
    @objc
    fileprivate func handleTouchDown(sender: UILongPressGestureRecognizer) {
//        switch sender.state {
//        case .began:
////            v.imageView.image = self.inputVideo.thumbnail
//        case .ended:
////            v.imageView.image = currentlySelectedImageThumbnail ?? self.inputVideo.thumbnail
//        default: ()
//        }
    }
    
    fileprivate func thumbFromImage(_ img: UIImage) -> CIImage {
        let k = img.size.width / img.size.height
        let scale = UIScreen.main.scale
        let thumbnailHeight: CGFloat = 300 * scale
        let thumbnailWidth = thumbnailHeight * k
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        UIGraphicsBeginImageContext(thumbnailSize)
        img.draw(in: CGRect(x: 0, y: 0, width: thumbnailSize.width, height: thumbnailSize.height))
        let smallImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return smallImage!.toCIImage()!
    }
    
    // MARK: - #########
    
    override public func viewDidAppear(_ animated: Bool) {
        trimmerView.asset = inputAsset
        trimmerView.delegate = self
        
        coverThumbSelectorView.asset = inputAsset
        coverThumbSelectorView.delegate = self
        
        selectTrim()
        videoView.loadVideo(inputVideo)

        super.viewDidAppear(animated)
//        collectionView.collectionViewLayout = layout()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlaybackTimeChecker()
        videoView.stop()
    }
    
    func setupRightBarButtonItem() {
        let rightBarButtonTitle = isFromSelectionVC ? YPConfig.wordings.done : YPConfig.wordings.next
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: rightBarButtonTitle,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(save))
        navigationItem.rightBarButtonItem?.tintColor = YPConfig.colors.tintColor
    }
    
    // MARK: - Top buttons

    @objc public func save() {
        guard let didSave = didSave else { return print("Don't have saveCallback") }
        navigationItem.rightBarButtonItem = YPLoaders.defaultLoader

        do {
            let asset = AVURLAsset(url: inputVideo.url)
            let trimmedAsset = try asset
                .assetByTrimming(startTime: trimmerView.startTime ?? CMTime.zero,
                                 endTime: trimmerView.endTime ?? inputAsset.duration)
            
            // Looks like file:///private/var/mobile/Containers/Data/Application
            // /FAD486B4-784D-4397-B00C-AD0EFFB45F52/tmp/8A2B410A-BD34-4E3F-8CB5-A548A946C1F1.mov
            let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingUniquePathComponent(pathExtension: YPConfig.video.fileType.fileExtension)
            
            try trimmedAsset.export(to: destinationURL) { [weak self] in
                guard let strongSelf = self else { return }
                
                DispatchQueue.main.async {
                    let resultVideo = YPMediaVideo(thumbnail: strongSelf.coverImageView.image!,
                                                   videoURL: destinationURL, asset: strongSelf.inputVideo.asset)
                    didSave(YPMediaItem.video(v: resultVideo))
                    strongSelf.setupRightBarButtonItem()
                }
            }
        } catch let error {
            print("💩 \(error)")
        }
    }
    
    @objc func cancel() {
        didCancel?()
    }
    
    // MARK: - Bottom buttons

    @objc public func selectTrim() {
        title = YPConfig.wordings.trim
        
        trimBottomItem.select()
        coverBottomItem.deselect()

        trimmerView.isHidden = false
        videoView.isHidden = false
        coverImageView.isHidden = true
        coverThumbSelectorView.isHidden = true
    }
    
    @objc public func selectCover() {
        title = YPConfig.wordings.cover
        
        trimBottomItem.deselect()
        coverBottomItem.select()
        
        trimmerView.isHidden = true
        videoView.isHidden = true
        coverImageView.isHidden = false
        coverThumbSelectorView.isHidden = false
        
        stopPlaybackTimeChecker()
        videoView.stop()
    }
    
    // MARK: - Various Methods

    // Updates the bounds of the cover picker if the video is trimmed
    // TODO: Now the trimmer framework doesn't support an easy way to do this.
    // Need to rethink a flow or search other ways.
    func updateCoverPickerBounds() {
        if let startTime = trimmerView.startTime,
            let endTime = trimmerView.endTime {
            if let selectedCoverTime = coverThumbSelectorView.selectedTime {
                let range = CMTimeRange(start: startTime, end: endTime)
                if !range.containsTime(selectedCoverTime) {
                    // If the selected before cover range is not in new trimeed range,
                    // than reset the cover to start time of the trimmed video
                }
            } else {
                // If none cover time selected yet, than set the cover to the start time of the trimmed video
            }
        }
    }
    
    // MARK: - Trimmer playback
    
    @objc func itemDidFinishPlaying(_ notification: Notification) {
        if let startTime = trimmerView.startTime {
            videoView.player.seek(to: startTime)
        }
    }
    
    func startPlaybackTimeChecker() {
        stopPlaybackTimeChecker()
        playbackTimeCheckerTimer = Timer
            .scheduledTimer(timeInterval: 0.05, target: self,
                            selector: #selector(onPlaybackTimeChecker),
                            userInfo: nil,
                            repeats: true)
    }
    
    func stopPlaybackTimeChecker() {
        playbackTimeCheckerTimer?.invalidate()
        playbackTimeCheckerTimer = nil
    }
    
    @objc func onPlaybackTimeChecker() {
        guard let startTime = trimmerView.startTime,
            let endTime = trimmerView.endTime else {
            return
        }
        
        let playBackTime = videoView.player.currentTime()
        trimmerView.seek(to: playBackTime)
        
        if playBackTime >= endTime {
            videoView.player.seek(to: startTime,
                                  toleranceBefore: CMTime.zero,
                                  toleranceAfter: CMTime.zero)
            trimmerView.seek(to: startTime)
        }
    }
}

// MARK: - TrimmerViewDelegate
extension YPVideoFiltersVC: TrimmerViewDelegate {
    public func positionBarStoppedMoving(_ playerTime: CMTime) {
        videoView.player.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        videoView.play()
        startPlaybackTimeChecker()
        updateCoverPickerBounds()
    }
    
    public func didChangePositionBar(_ playerTime: CMTime) {
        stopPlaybackTimeChecker()
        videoView.pause()
        videoView.player.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
}

// MARK: - ThumbSelectorViewDelegate
extension YPVideoFiltersVC: ThumbSelectorViewDelegate {
    public func didChangeThumbPosition(_ imageTime: CMTime) {
        if let imageGenerator = imageGenerator,
            let imageRef = try? imageGenerator.copyCGImage(at: imageTime, actualTime: nil) {
            coverImageView.image = UIImage(cgImage: imageRef)
        }
    }
}

extension YPVideoFiltersVC {
    func getThumbnailFrom(path: URL) -> UIImage? {
        
        do {
            
            let asset = AVURLAsset(url: path , options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            
            return thumbnail
            
        } catch let error {
            
            print("*** Error generating thumbnail: \(error.localizedDescription)")
            return nil
            
        }
        
    }
}
// MARK: - UICollectionViewDelegate
extension YPVideoFiltersVC: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredThumbnailImagesArray.count
    }
    
    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let filter = filters[indexPath.row]
        let image = filteredThumbnailImagesArray[indexPath.row]
        if let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: "FilterCell",
                                 for: indexPath) as? YPFilterCollectionViewCell {
//               cell.imageView.contentMode = .scaleToFill
            cell.name.text = filter.name
            cell.imageView.image = image
            return cell
        }
        return UICollectionViewCell()
    }
}

extension YPVideoFiltersVC: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedFilter = filters[indexPath.row]
        currentlySelectedImageThumbnail = filteredThumbnailImagesArray[indexPath.row]
        //Check Video Priview
        //        self.v.imageView.image = currentlySelectedImageThumbnail
    }
}
extension YPVideoFiltersVC : UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        return CGSize(width: collectionView.frame.size.height - 20, height: collectionView.frame.size.height)
    }

    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4.0
    }
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
         return 4.0
    }
    
    
}
