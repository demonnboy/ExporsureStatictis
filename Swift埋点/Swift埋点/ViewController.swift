//
//  ViewController.swift
//  Swift埋点
//
//  Created by Demon on 2019/12/2.
//  Copyright © 2019 Demon. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var redView: UIView?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 100, width: self.view.frame.width, height: 100))
        scroll.contentSize = CGSize(width: 20 * 50, height: 100)
        
        for i in 0..<20 {
            let v = UILabel(frame: CGRect(x: i*50, y: 0, width: 50, height: 100))
            v.backgroundColor = UIColor(white: CGFloat(arc4random()%10) / 10.0, alpha: 1.0)
            v.text = "\(i)"
            v.sh_trackTag(observe: self, identifier: "scroll", param: ["index": "\(i)"])
            scroll.addSubview(v)
        }
        self.view.addSubview(scroll)
        
        
        let tableview = UITableView(frame: CGRect(x: 0, y: 200, width: 100, height: 300), style: UITableView.Style.plain)
        tableview.dataSource = self
        tableview.delegate  = self
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.view.addSubview(tableview)
        
        
        let redView = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 100))
        redView.backgroundColor = UIColor.red
        self.view.addSubview(redView)
        redView.sh_trackTag(observe: self, identifier: "redView", param: ["exposekey": "12312312"])
        self.redView = redView
    }
    
    override func sh_viewVisibleAuth() -> Bool {
        return true
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            self.navigationController?.pushViewController(ViewController(), animated: true)
        } else {
            self.redView?.isHidden = !self.redView!.isHidden
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "\(indexPath.row)"
        cell.sh_trackTag(observe: self, identifier: "uitableview", param: ["index":"\(indexPath.section)" + "." + "\(indexPath.row)", "id": self.uniqueId()])
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
    }
    
}


