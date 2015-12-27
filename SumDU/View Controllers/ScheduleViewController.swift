//
//  ScheduleViewController.swift
//  SumDU
//
//  Created by Yura on 20.12.15.
//  Copyright © 2015 AppDecAcademy. All rights reserved.
//

import UIKit
import SwiftyJSON

class ScheduleViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var scheduleNavigation: UINavigationItem!
    
    // MARK: - Constants
    
    private let kCellReuseIdentifier = "kCellReuseIdentifierSchedule"
    
    /// Schedule table sections
    private let allSections = [
        keyMonday,
        keyTuesday,
        keyWednesday,
        keyThursday,
        keyFriday,
        keySaturday
    ]
    
     // MARK: - Variables
    
    /// Data from SearchController
    var listData: ListData?
    
    /// Object of Parser class
    var parser = Parser()
    
    /// Parameters for shcedule request
    var requestData : [String : String] = ["" : ""]
    
    /// Schedule records separetad by sections
    var recordsBySections = Array<Array<Schedule>>()
    
    var refreshControl = UIRefreshControl()
    
    /// Sections for single schedule request
    var sectionsInTable: [String] = []


    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Remove separators for empty cells
        tableView.tableFooterView = UIView(frame: CGRectZero)
        
        // Please, explain this line again
        self.tableView.registerClass(ScheduleCell.self, forCellReuseIdentifier: kCellReuseIdentifier)
        
        // Delegate relations here
        parser.scheduleDelegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        // Set title to navigation bar
        scheduleNavigation.title = listData?.name
        
        // Set up the refresh control
        self.refreshControl.attributedTitle = NSAttributedString(string: "Потяните для обновления")
        self.refreshControl.addTarget(self, action: "refresh", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView?.addSubview(refreshControl)
        
        // Load schedule for selected row
        self.loadShedule()
        
    }
    
    /// Refresh shcedule table
    func refresh() {
        self.loadShedule()
    }
    
    /// Prepea and send schedule request in controller
    func loadShedule() {
        
        // Prepea request data
        var startDate = ""
        var endDate = ""
        var groupId = "0"
        var teacherId = "0"
        var auditoriumId = "0"
        
        // Detect request type
        if let selectedType = listData?.type {
            
            if let selectedId = listData?.id {
                
                let id = String(selectedId)
                
                switch selectedType {
                case ListDataType.Group:
                    groupId = id
                case ListDataType.Teacher:
                    teacherId = id
                case ListDataType.Auditorium:
                    auditoriumId = id
                }
            }
        }
        
        // Get start date
        let currentDate = NSDate()
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        startDate = dateFormatter.stringFromDate(currentDate)
        
        // Get end date
        let additionalDays = 7
        let components = NSDateComponents()
        components.day = additionalDays
        // important: NSCalendarOptions(0)
        let futureDate = NSCalendar.currentCalendar()
            .dateByAddingComponents(components, toDate: currentDate, options: NSCalendarOptions(rawValue: 0))
        endDate = dateFormatter.stringFromDate(futureDate!)
        
        
        // Schedule request parametes
        requestData =
            [
                ScheduleRequestParameter.BeginDate.rawValue: startDate,
                ScheduleRequestParameter.EndDate.rawValue: endDate,
                ScheduleRequestParameter.GroupId.rawValue: groupId,
                ScheduleRequestParameter.NameId.rawValue: teacherId,
                ScheduleRequestParameter.LectureRoomId.rawValue: auditoriumId,
                ScheduleRequestParameter.PublicDate.rawValue: "true",
                ScheduleRequestParameter.Param.rawValue: "0"
        ]
        
        // send request with parameters to get records of schedule
        parser.sendScheduleRequest(requestData)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /// Reload schedule, send new request
    @IBAction func refreshSchedule(sender: AnyObject) {
            self.loadShedule()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

// MARK: - UITableViewDelegate

extension ScheduleViewController: UITableViewDelegate { }

// MARK: - UITableViewDataSource

extension ScheduleViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionsInTable[section]
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sectionsInTable.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordsBySections[section].count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier(kCellReuseIdentifier, forIndexPath: indexPath) as! ScheduleCell
        let text = recordsBySections[indexPath.section][indexPath.row].pairOrderName + " " +
            recordsBySections[indexPath.section][indexPath.row].groupName + " в " +
            recordsBySections[indexPath.section][indexPath.row].auditoriumName
        
        // TODO: Send value to prototype cell
//        cell.pairName.text = "111"
        
        cell.textLabel?.text = text
        return cell
    }
}

// MARK: - ParserScheduleDelegate

extension ScheduleViewController: ParserScheduleDelegate {
    
    func getSchedule(response: JSON) {
        
        if let jsonArray = response.array where jsonArray.count > 0 {
            
            // clear data arrays before usage
            recordsBySections = Array<Array<Schedule>>()
            sectionsInTable = []
            
            // Iterate thrue all available sections
            for oneSection in allSections {
                
                // Array of single section
                var singleSection: [Schedule] = []
                
                // Iterate all elements in json array
                for subJson in jsonArray {
                    
                    // Init schedule object
                    if let scheduleRecord = Schedule(record: subJson) {
                        
                        // If day of week in schedule object equals to section day
                        if oneSection == scheduleRecord.dayOfWeek {
                            
                            // Append schedule record in section
                            singleSection.append(scheduleRecord)
                        }
                    }
                }
                
                // Combine all not empty sections together
                if singleSection.count > 0 {
                    
                    // Sorting recird in schedule section by pair
                    let sortedSection = singleSection.sort({
                        $0.pairOrderName.compare($1.pairOrderName) == .OrderedAscending
                    })
                    
                    // Final append to array
                    recordsBySections.append(sortedSection)
                    sectionsInTable.append(oneSection)
                }
            }
        }

        // tell refresh control it can stop showing up now
        if self.refreshControl.refreshing
        {
            self.refreshControl.endRefreshing()
        }

//         Reload table data after fill an array
        tableView.reloadData()
    }
}
