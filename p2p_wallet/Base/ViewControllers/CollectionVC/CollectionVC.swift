//
//  CollectionVC.swift
//  p2p_wallet
//
//  Created by Chung Tran on 11/3/20.
//

import Foundation
import IBPCollectionViewCompositionalLayout
import DiffableDataSources
import RxSwift

protocol CollectionCell: BaseCollectionViewCell {
    associatedtype T: Hashable
    func setUp(with item: T)
}

class CollectionVC<ItemType: Hashable, Cell: CollectionCell>: BaseVC {
    // MARK: - Nested type
    struct SectionHeader {
        let headerTitle: String
        var headerFont: UIFont = .systemFont(ofSize: 17, weight: .semibold)
    }
    
    // MARK: - Properties
    var dataSource: CollectionViewDiffableDataSource<String, ItemType>!
    let viewModel: ListViewModel<ItemType>
    var sectionHeaders: [SectionHeader] { [] }
    
    override var scrollViewAvoidingTabBar: UIScrollView? {collectionView}
    
    lazy var collectionView: BaseCollectionView = {
        let collectionView = BaseCollectionView(frame: .zero, collectionViewLayout: createLayout())
        return collectionView
    }()
    
    init(viewModel: ListViewModel<ItemType>) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.reload()
    }
    
    // MARK: - Setup
    override func setUp() {
        super.setUp()
        view.addSubview(collectionView)
        collectionView.autoPinEdgesToSuperviewEdges()
        
        registerCellAndSupplementaryViews()
        configureDataSource()
    }
    
    func registerCellAndSupplementaryViews() {
        collectionView.registerCells([Cell.self])
    }
    
    // MARK: - Binding
    override func bind() {
        super.bind()
        bindList()
    }
    
    var combinedObservable: Observable<Void> {
        viewModel.state.distinctUntilChanged()
            .map {_ in ()}
    }
    
    func bindList() {
        combinedObservable
            .subscribe(onNext: { (_) in
                let snapshot = self.mapDataToSnapshot()
                self.dataSource.apply(snapshot)
                DispatchQueue.main.async {
                    self.dataDidLoad()
                }
            })
            .disposed(by: disposeBag)
    }
    
    func mapDataToSnapshot() -> DiffableDataSourceSnapshot<String, ItemType> {
        DiffableDataSourceSnapshot<String, ItemType>()
    }
    
    func dataDidLoad() {
        
    }
    
    // MARK: - Layout
    func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { (sectionIndex: Int, env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            self.createLayoutForSection(sectionIndex, environment: env)
        }
    }
    
    func createLayoutForSection(_ sectionIndex: Int, environment env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        let group: NSCollectionLayoutGroup
        // 1 columns
        if env.container.contentSize.width < 536 {
            group = createLayoutForGroupOnSmallScreen(sectionIndex: sectionIndex, env: env)
        // 2 columns
        } else {
            group = createLayoutForGroupOnLargeScreen(sectionIndex: sectionIndex, env: env)
        }
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        return section
    }
    
    func createLayoutForGroupOnSmallScreen(sectionIndex: Int, env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutGroup {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(env.container.contentSize.width - 32), heightDimension: .estimated(200))
        
        return NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
    }
    
    func createLayoutForGroupOnLargeScreen(sectionIndex: Int, env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutGroup {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
        
        let leadingItem = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let trailingItem = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute((env.container.contentSize.width - 32 - 16)/2), heightDimension: .estimated(300))
        
        let leadingGroup = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [leadingItem])
        
        let trailingGroup = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [trailingItem])
        
        let combinedGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: combinedGroupSize, subitems: [leadingGroup, trailingGroup])
        group.interItemSpacing = .fixed(16)
        return group
    }
    
    // MARK: - Datasource
    private func configureDataSource() {
        dataSource = CollectionViewDiffableDataSource<String, ItemType>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, item: ItemType) -> UICollectionViewCell? in
            self.configureCell(collectionView: collectionView, indexPath: indexPath, item: item)
        }
                
        dataSource.supplementaryViewProvider = { (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            self.configureSupplementaryView(collectionView: collectionView, kind: kind, indexPath: indexPath)
        }
    }
    
    func configureCell(collectionView: UICollectionView, indexPath: IndexPath, item: ItemType) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: Cell.self), for: indexPath) as? Cell
        cell?.setUp(with: item as! Cell.T)
        return cell ?? UICollectionViewCell()
    }
    
    func configureSupplementaryView(collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? {
        if kind == UICollectionView.elementKindSectionHeader {
            return configureHeaderForSectionAtIndexPath(indexPath, inCollectionView: collectionView)
        }
        if kind == UICollectionView.elementKindSectionFooter {
            return configureFooterForSectionAtIndexPath(indexPath, inCollectionView: collectionView)
        }
        return nil
    }
    
    func configureHeaderForSectionAtIndexPath(_ indexPath: IndexPath, inCollectionView collectionView: UICollectionView) -> UICollectionReusableView? {
        guard sectionHeaders.count > indexPath.section else {
            return nil
        }
        
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SectionHeaderView",
            for: indexPath) as? SectionHeaderView
        
        view?.setUp(headerTitle: sectionHeaders[indexPath.section].headerTitle, headerFont: sectionHeaders[indexPath.section].headerFont)
        return view
    }
    
    func configureFooterForSectionAtIndexPath(_ indexPath: IndexPath, inCollectionView collectionView: UICollectionView) -> UICollectionReusableView? {
        nil
    }
}
