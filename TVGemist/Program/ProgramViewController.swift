//
//  ProgramViewController.swift
//  NPO
//
//  Created by Jeroen Wesbeek on 29/10/2017.
//  Copyright © 2017 Jeroen Wesbeek. All rights reserved.
//

import UIKit
import XCGLogger
import NPOKit

class ProgramViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    private var program: Program?
    private var paginator: Paginator<Episode>?
    private var episodes = [Episode]()
    private var headerImageTask: URLSessionDataTask?
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // register suplementary views
        collectionView.register(UINib(nibName: ProgramCollectionReusableView.nibName, bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: ProgramCollectionReusableView.reuseIdentifier)
        
        // register cells
        collectionView.register(UINib(nibName: EpisodeCollectionViewCell.nibName, bundle: nil), forCellWithReuseIdentifier: EpisodeCollectionViewCell.reuseIdentifier)
        
        setupPaginator()
    }
    
    // MARK: Configuration
    
    func configure(withProgram program: Program) {
        self.program = program
    }

    // MARK: Networking
    
    private func setupPaginator() {
        guard let program = program else { return }
        
        paginator = NPOKit.shared.getEpisodePaginator(for: program) { [weak self] (result) in
            switch result {
            case .success(let paginator, let episodes):
                log.debug("Page \(paginator.page) of \(paginator.numberOfPages) (\(episodes.count) episodes)")
                self?.add(new: episodes)
            case .failure(let error as NPOError):
                log.error("Could not fetch episodes (\(error.localizedDescription))")
            case.failure(let error):
                log.error("Could not fetch episodes (\(error.localizedDescription))")
            }
        }
        
        // fetch the first page
        paginator?.next()
    }
    
    // MARK: Adding episodes
    
    private func add(new newEpisodes: [Episode]) {
        var indexPaths = [IndexPath]()
        
        for episode in newEpisodes {
            indexPaths.append(IndexPath(row: episodes.count, section: 0))
            episodes.append(episode)
        }
        
        collectionView?.insertItems(at: indexPaths)
    }
}

// MARK: UIScrollViewDelegate
extension ProgramViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView = collectionView, let paginator = paginator else { return }
        
        let numberOfPagesToInitiallyFetch = 2
        let yOffsetToLoadNextPage = collectionView.contentSize.height - (collectionView.bounds.height * CGFloat(numberOfPagesToInitiallyFetch))
        
        guard scrollView.contentOffset.y > yOffsetToLoadNextPage else { return }
        
        paginator.next()
    }
}

// MARK: UICollectionViewDataSource
extension ProgramViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return episodes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        //swiftlint:disable:next force_cast
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EpisodeCollectionViewCell.reuseIdentifier, for: indexPath) as! EpisodeCollectionViewCell
        cell.configure(withEpisode: episodes[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionElementKindSectionHeader else {
            fatalError("Unsupported supplementary element of kind: \(kind)")
        }
        
        //swiftlint:disable:next force_cast
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionHeader, withReuseIdentifier: ProgramCollectionReusableView.reuseIdentifier, for: indexPath) as! ProgramCollectionReusableView
        if let program = program {
            view.configure(withProgram: program)
        }
        return view
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension ProgramViewController: UICollectionViewDelegateFlowLayout {
    // MARK: Getting the Size of Items
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return EpisodeCollectionViewCell.size
    }
    
    // MARK: Getting the Header and Footer Sizes
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return ProgramCollectionReusableView.size
    }
}

// MARK: UICollectionViewDelegate
extension ProgramViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        guard let cell = collectionView.visibleCells.first(where: { $0.isFocused }) as? EpisodeCollectionViewCell, let episodeImage = cell.episodeImage else { return }
        backgroundImageView.image = episodeImage
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        play(episode: episodes[indexPath.row])
    }
}

// MARK: Playback
extension ProgramViewController {
    private func play(episode: Episode) {
//        let isFairPlayEnabled = false
//
//        if isFairPlayEnabled {
//            log.error("FairPlay support not implemented")
//        } else {
            legacyPlay(episode: episode)
//        }
    }
    
    private func legacyPlay(episode: Episode) {
        // play the legacy HLS Stream
        NPOKit.shared.legacyPlaylist(for: episode) { [weak self] (result) in
            switch result {
            case .success(let legacyPlaylist):
                self?.play(playlist: legacyPlaylist)
            case .failure(let error as NPOError):
                log.error("Could not fetch playlist for episode (\(error.localizedDescription))")
            case.failure(let error):
                log.error("Could not fetch playlist for episode (\(error.localizedDescription))")
            }
        }
    }

    private func play(playlist: LegacyPlaylist) {
        let playerViewController = LegacyPlayerViewController.fromStoryboard()
        present(playerViewController, animated: true) {
            playerViewController.play(playlist: playlist)
        }
    }
}