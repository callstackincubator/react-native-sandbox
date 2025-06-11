//
//  SplitViewController.swift
//  MultiInstancePOC
//
//  Created by Mariusz Pasinski on 06/06/2025.
//
import UIKit

class SplitViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
  }

  public func setViews(topView: UIView, bottomView: UIView) {
    view.addSubview(topView)
    view.addSubview(bottomView)

    topView.translatesAutoresizingMaskIntoConstraints = false
    bottomView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      topView.topAnchor.constraint(equalTo: view.topAnchor),
      topView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      topView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      topView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1 / 2.0),

      bottomView.topAnchor.constraint(equalTo: topView.bottomAnchor),
      bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }
}
