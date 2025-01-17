//
//  ListView.swift
//  KVKCalendar
//
//  Created by Sergei Kviatkovskii on 26.12.2020.
//

#if os(iOS)

import UIKit

public final class ListView: UIView, CalendarSettingProtocol {
    
    public struct Parameters {
        var style: Style
        let data: ListViewData
        
        public init(style: Style, data: ListViewData) {
            self.style = style
            self.data = data
        }
    }
    
    public weak var dataSource: CalendarDataSource?
    public weak var delegate: CalendarDelegate?
    
    var style: Style {
        get {
            params.style
        }
        set {
            params.style = newValue
        }
    }
    
    private var params: Parameters
    var lastVelocityYSign = 0
    public lazy var tableView: UITableView = {
        let table = UITableView()
        table.tableFooterView = UIView()
        table.dataSource = self
        table.delegate = self
        if #available(iOS 15.0, *) {
            table.sectionHeaderTopPadding = 0
        }
        return table
    }()
    
    private var listStyle: ListViewStyle {
        params.style.list
    }
    
    public init(parameters: Parameters, frame: CGRect? = nil) {
        self.params = parameters
        super.init(frame: frame ?? .zero)
        addSubview(tableView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupConstraints() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        let top = tableView.topAnchor.constraint(equalTo: topAnchor)
        let bottom = tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        let left = tableView.leftAnchor.constraint(equalTo: leftAnchor)
        let right = tableView.rightAnchor.constraint(equalTo: rightAnchor)
        NSLayoutConstraint.activate([top, bottom, left, right])
    }
    
    func updateStyle(_ style: Style, force: Bool) {
        self.style = style
        setUI(reload: force)
    }
    
    func setUI(reload: Bool = false) {
        backgroundColor = listStyle.backgroundColor
        tableView.backgroundColor = listStyle.backgroundColor
    }
    
    func reloadFrame(_ frame: CGRect) {
        self.frame = frame
        layoutIfNeeded()
    }
    
    func reloadData(_ events: [Event]) {
        params.data.reloadEvents(events)
        tableView.reloadData()
    }
    
    func reloadSectionData(_ events: [Event],indexpath:IndexPath) {
        params.data.reloadEvents(events)
        tableView.reloadSections(IndexSet(integer: indexpath.section), with: .none)
    }
    
    func showSkeletonVisible(_ visible: Bool) {
        params.data.isSkeletonVisible = visible
        tableView.reloadData()
    }
    
    func setDate(_ date: Date, animated: Bool) {
        params.data.date = date
        
        guard !params.data.isSkeletonVisible else { return }
        
        if let idx = params.data.sections.firstIndex(where: { $0.date.isEqual(date) }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: idx), at: .top, animated: animated)
            }
        } else if let idx = params.data.sections.firstIndex(where: { $0.date.kvkYear == date.kvkYear && $0.date.kvkMonth == date.kvkMonth }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: idx), at: .top, animated: animated)
            }
        } else if let idx = params.data.sections.firstIndex(where: { $0.date.kvkYear == date.kvkYear }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: idx), at: .top, animated: animated)
            }
        }
    }
    
}

extension ListView: UITableViewDataSource, UITableViewDelegate {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        params.data.numberOfSection()
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        params.data.numberOfItemsInSection(section)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !params.data.isSkeletonVisible else {
            return tableView.kvkDequeueCell { (cell: ListViewCell) in
                cell.setSkeletons(params.data.isSkeletonVisible)
            }
        }
        
        let event = params.data.event(indexPath: indexPath)
        if let cell = dataSource?.dequeueCell(parameter: .init(date: event.start), type: .list, view: tableView, indexPath: indexPath,event:event) as? UITableViewCell {
            return cell
        } else {
            return tableView.kvkDequeueCell(indexPath: indexPath) { (cell: ListViewCell) in
                cell.txt = event.title.list
                cell.dotColor = event.color?.value
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !params.data.isSkeletonVisible else {
            return tableView.kvkDequeueView { (view: ListViewHeader) in
                view.setSkeletons(params.data.isSkeletonVisible)
            }
        }
        
        let date = params.data.sections[section].date
        let isShowHeader = params.data.sections[section].isShowHeader
        if let headerView = dataSource?.dequeueHeader(date: date,isShowHeader:isShowHeader, type: .list, view: tableView, indexPath: IndexPath(row: 0, section: section),events:params.data.sections[section].events) as? UIView {
            return headerView
        } else {
            return tableView.kvkDequeueView { (view: ListViewHeader) in
                view.title = params.data.titleOfHeader(section: section,
                                                       formatter: params.style.list.headerDateFormatter,
                                                       locale: params.style.locale)
                view.didTap = { [weak self] in
                    self?.delegate?.didSelectDates([date], type: .list, frame: view.frame)
                }
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard !params.data.isSkeletonVisible else {
            return 45
        }
        
        let event = params.data.event(indexPath: indexPath)
        if let height = delegate?.sizeForCell(event.start, type: .list)?.height {
            return height
        } else{
            return UITableView.automaticDimension
        }
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard !params.data.isSkeletonVisible else {
            return 50
        }
        
        let date = params.data.sections[section].date
        if let height = delegate?.sizeForHeader(date, type: .list)?.height {
            return height
        } else if let height = params.style.list.heightHeaderView {
            return height
        } else {
            return UITableView.automaticDimension
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let event = params.data.event(indexPath: indexPath)
        let frameCell = tableView.cellForRow(at: indexPath)?.frame
        delegate?.didSelectEvent(event, type: .list, frame: frameCell)
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let event = params.data.event(indexPath: indexPath)
        var direction: EventScrollDirection = .netural
        if lastVelocityYSign < 0{
            direction = .down
            lastVelocityYSign = 0
        }
        else if lastVelocityYSign > 0{
            direction = .up
            lastVelocityYSign = 0
        }
        delegate?.willDisplaySections(event, type: .list, tableView: tableView, list: params.data.sections, indexPath: indexPath,scrollDirection: direction)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentVelocityY =  scrollView.panGestureRecognizer.velocity(in: scrollView.superview).y
        let currentVelocityYSign = Int(currentVelocityY).signum()
        if currentVelocityYSign != lastVelocityYSign &&
            currentVelocityYSign != 0 {
            lastVelocityYSign = currentVelocityYSign
        }
        if currentVelocityYSign == 1 && params.data.sections.count < 2{
            delegate?.willDisplaySections(params.data.sections[0].events[0], type: .list, tableView: tableView, list: params.data.sections, indexPath: IndexPath(row: 0, section: 0),scrollDirection: .up)
        }
    }
    
    
}

#endif
