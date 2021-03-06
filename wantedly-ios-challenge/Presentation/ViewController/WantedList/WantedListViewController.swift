//
//  WantedListViewController.swift
//  wantedly-ios-challenge
//
//  Created by 下村一将 on 2017/12/29.
//  Copyright © 2017年 kazu. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

final class WantedListViewController: UIViewController {
	static func make() -> WantedListViewController {
		return R.storyboard.wantedListViewController.instantiateInitialViewController()!
	}
	
	@IBOutlet weak var searchBar: UISearchBar!
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var indicatorView: UIActivityIndicatorView!
	
	private var viewModel: WantedListViewModelType!
	private let disposeBag = DisposeBag()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel = WantedListViewModel(
			searchingText: searchBar.rx.text.orEmpty.asDriver(),
			selectedIndexPath: collectionView.rx.itemSelected.asDriver(),
			reachedToBottom: collectionView.rx.reachedBottom.asDriver()
		)
		
		setupUI()
		bind()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}
	
	func setupUI() {
		self.title = "募集一覧"
		self.view.backgroundColor = UIColor(hexString: "#191D1FFF")
		
		searchBar.setScopeBarButtonTitleTextAttributes([NSAttributedStringKey.font.rawValue: UIFont.systemFont(ofSize: 14)], for: UIControlState.normal)
		searchBar.barTintColor = UIColor(hexString: "#49A2B8FF")
		if let field: UITextField = searchBar.value(forKey: "_searchField") as? UITextField {
			field.font = UIFont.systemFont(ofSize: 12)
			field.backgroundColor = UIColor(hexString: "#FFFFFF33")
			field.textColor = UIColor.white
			field.attributedPlaceholder = NSAttributedString(string: "地域や特徴など条件を追加",
															 attributes: [NSAttributedStringKey.foregroundColor: UIColor(hexString: "#FFFFFFAA")!])
		}
		
		let nib = R.nib.wantedListCollectionViewCell()
		collectionView.register(nib, forCellWithReuseIdentifier: R.reuseIdentifier.wantedListCollectionViewCell.identifier)
		
		collectionView.keyboardDismissMode = .onDrag
		indicatorView.activityIndicatorViewStyle = .whiteLarge
		indicatorView.color = .red
		self.view.addSubview(indicatorView)
		
		if self.traitCollection.forceTouchCapability == UIForceTouchCapability.available { // For 3DTouch
			self.registerForPreviewing(with: self, sourceView: view)
		}
	}
	
	func bind() {
		let cellIdentifier = R.reuseIdentifier.wantedListCollectionViewCell.identifier
		viewModel.items
			.asDriver()
			.drive(collectionView.rx.items(cellIdentifier: cellIdentifier, cellType: WantedListCollectionViewCell.self)) { _, model, cell in
				cell.contentView.alpha = 0
				cell.updateCell(listModel: model)
			}
			.disposed(by: disposeBag)
		
		viewModel.pushWantedDetailViewController
			.drive(onNext: { [weak self] listModel in
				self?.pushWantedDetailViewController(with: listModel)
			})
			.disposed(by: disposeBag)
		
		viewModel
			.isLoading
			.asDriver()
			.drive(self.indicatorView.rx.isAnimating)
			.disposed(by: disposeBag)
		
		viewModel
			.isLoading
			.asDriver()
			.map { !$0 }
			.drive(self.indicatorView.rx.isHidden)
			.disposed(by: disposeBag)
		
		viewModel
			.occuredError
			.asObservable()
			.flatMap {
				$0.flatMap { Observable.just($0) } ?? Observable.empty()
			}
			.subscribe {
				switch $0.event {
				case .next(let v):
					let alertController = UIAlertController(title: "エラー", message: v.localizedDescription, preferredStyle: .alert)
					self.present(alertController, animated: true, completion: {
						DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
							self.dismiss(animated: true, completion: nil)
						}
					})
				default:
					break
				}
			}
			.disposed(by: disposeBag)
	}
	
	private func pushWantedDetailViewController(with listModel: WantedListModel) {
		let viewController = WantedDetailViewController.make(listModel: listModel)
		navigationController?.pushViewController(viewController, animated: true)
	}
}

extension WantedListViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		UIView.animate(withDuration: 0.4, delay: 0, options: .allowUserInteraction, animations: { () -> Void in
			cell.contentView.alpha = 1
		}, completion: nil)
	}
}

extension WantedListViewController: UISearchBarDelegate {
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchBar.resignFirstResponder()
	}
}

extension WantedListViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		return CGSize(width: self.view.bounds.width, height: 300)
	}
	
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
		return UIEdgeInsets(top: 8.0, left: 0, bottom: 0, right: 0)
	}
}

extension WantedListViewController: UIViewControllerPreviewingDelegate {
	@available(iOS 9.0, *)
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
		let point = collectionView.convert(location, from: collectionView.superview)
		guard let indexPath = collectionView.indexPathForItem(at: point) else {
			return nil
		}
		if let attr = collectionView.layoutAttributesForItem(at: indexPath) {
			let rect = collectionView.convert(attr.frame, to: collectionView.superview)
			previewingContext.sourceRect = rect
		}
		guard let model = viewModel?.items.value[indexPath.row] else {
			return nil
		}
		return WantedDetailViewController.make(listModel: model)
	}
	
	@available(iOS 9.0, *)
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
		self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
	}
}
