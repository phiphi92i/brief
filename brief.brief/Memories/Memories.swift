//  Memories.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 08/04/2024.



import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Nuke
import NukeUI
import FirebaseAnalytics


struct MemoriesCalendarView: View {
    var userID: String // Add this line
    @StateObject private var viewModel: MemoriesCalendarViewModel

    init(userID: String) {
        self.userID = userID
        self._viewModel = StateObject(wrappedValue: MemoriesCalendarViewModel(userId: userID))
    }
    
    private let weekdayAbbreviations = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.monthSections, id: \.self) { monthSection in
                Text(monthSection.monthYearString)
                    .font(.title2)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                    ForEach(weekdayAbbreviations, id: \.self) { weekday in
                        Text(weekday)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                    
                    ForEach(monthSection.days, id: \.self) { day in
                        if let post = viewModel.posts.first(where: { $0.timestamp.isSameDay(as: day) }) {
                            MemoryCell(post: post)
                                .onTapGesture {
                                    viewModel.selectedPost = post
                                    Analytics.logEvent("memory_cell_clicked", parameters: [
                                                                "post_id": post.id ?? "Unknown",
                                                                "user_id": post.userID,
                                                                "timestamp": "\(post.timestamp)"
                                                            ])
                                }
                        } else {
                            Text(day.dayString)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .frame(width: 50, height: 50)
//                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $viewModel.selectedPost) { post in
            MemoriesPostView(selectedDate: post.timestamp, userID: post.userID, postId: post.id ?? "", cameraViewModel: CameraViewModel(), commentCameraService: CommentCameraService())
        }
    }
}

struct MemoryTextCell: View {
    let post: UserPost
    let hasCurrentUserPostedRecently: Bool

    var body: some View {
        Text(post.content)
            .foregroundColor(.black)
            .padding(.bottom, 5)
            .padding(.horizontal, 10)
            .blur(radius: hasCurrentUserPostedRecently ? 0 : 10)
    }
}


struct MemoryCell: View {
    let post: UserPost

    var body: some View {
        LazyImage(url: URL(string: post.images.first ?? "")) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .overlay(
                        Text(post.timestamp.dayString)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    )
                    .cornerRadius(10)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                Color.gray.opacity(0.3)
                    .cornerRadius(10)
                    .overlay(
                        Text(post.timestamp.dayString)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}


class MemoriesCalendarViewModel: ObservableObject {
    @Published var days: [Date]
    @Published var posts: [UserPost] = []
    @Published var selectedPost: UserPost?
    @Published var monthSections: [MonthSection] = []
    var userId: String // Add this line
    
    
    init(userId: String) {
        self.userId = userId
        let currentDate = Date()
        let currentMonth = Calendar.current.component(.month, from: currentDate)
        let currentYear = Calendar.current.component(.year, from: currentDate)
        
        let startOfOctober2023 = Calendar.current.date(from: DateComponents(year: 2023, month: 10, day: 1))!
        self.days = Date.generateDatesArrayBetweenTwoDates(startDate: startOfOctober2023, endDate: currentDate)
        groupDaysByMonth()
        fetchMemories()
    }
    
    
    
    private func groupDaysByMonth() {
        let groupedDictionary = Dictionary(grouping: days, by: { $0.startOfMonth })
        let sortedKeys = groupedDictionary.keys.sorted(by: { $0 > $1 })
        monthSections = sortedKeys.map { month in
            let daysInMonth = groupedDictionary[month] ?? []
            return MonthSection(monthYearString: month.monthYearString, days: daysInMonth.reversed()) // Here we reverse the order of days
        }
    }
    
    
    private func fetchMemories() {
        let firestoreRef = Firestore.firestore().collection("posts").whereField("userID", isEqualTo: userId)
        
        // Add a filter for the timestamp to be within the range of the days array
        let startDate = Date.getStartOfMonth(month: 10, year: 2023) // April 1, 2024
        let endDate = days.last!
        let startTimestamp = Timestamp(date: startDate)
        let endTimestamp = Timestamp(date: endDate.addingTimeInterval(24 * 60 * 60 - 1)) // Add 23 hours and 59 minutes to include the last day
        
        firestoreRef
            .whereField("timestamp", isGreaterThanOrEqualTo: startTimestamp)
            .whereField("timestamp", isLessThanOrEqualTo: endTimestamp)
            .getDocuments { (querySnapshot, error) in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching documents: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                
                var posts: [UserPost] = []
                for document in documents {
                    let data = document.data()
                    let id = document.documentID
                    let content = data["content"] as? String ?? ""
                    let images = data["images"] as? [String] ?? []
                    let userID = data["userID"] as? String ?? ""
                    let username = data["username"] as? String ?? ""
                    let profileImageUrl = data["profileImageUrl"] as? String ?? ""
                    let distributionCircles = data["distributionCircles"] as? [String] ?? []
                    let likes = data["likes"] as? [String] ?? []
                    let audioURLString = data["audioURL"] as? String ?? ""
                    let audioURL = URL(string: audioURLString)
                    
                    let firestoreTimestamp = data["timestamp"] as? Timestamp
                    let originalTimestamp = firestoreTimestamp?.dateValue() ?? Date()
                    
                    let expirationTimestamp = data["expiresAt"] as? Timestamp
                    let originalExpirationTime = expirationTimestamp?.dateValue() ?? originalTimestamp.addingTimeInterval(24 * 60 * 60)
                    
                    var location: UserPost.UserLocation? = nil
                    
                    // Optional location data fetching
                    if let locationData = data["location"] as? [String: Any],
                       let latitude = locationData["latitude"] as? Double,
                       let longitude = locationData["longitude"] as? Double,
                       let address = locationData["address"] as? String {
                        location = UserPost.UserLocation(latitude: latitude, longitude: longitude, address: address)
                    }
                    
                    let userPost = UserPost(id: id, content: content, timestamp: originalTimestamp, expiresAt: originalExpirationTime, userID: userID, username: username, profileImageUrl: profileImageUrl, distributionCircles: distributionCircles, images: images, likes: likes, audioURL: audioURL, location: location, isGlobalPost: false, hasSecondaryImage: false)
                    posts.append(userPost)
                }
                
                DispatchQueue.main.async {
                    self.posts = posts.sorted(by: { $0.timestamp > $1.timestamp })
                }
            }
    }
}

struct MonthSection: Hashable {
    let monthYearString: String
    let days: [Date]
}

extension Date {
    func isSameDay(as otherDate: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: otherDate)
    }

    var dayString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"
        return dateFormatter.string(from: self)
    }

    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components)!
    }

    var monthYearString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: self)
    }


    static func generateDatesArrayBetweenTwoDates(startDate: Date, endDate: Date) -> [Date] {
        var datesArray: [Date] = []
        var startDate = startDate
        let calendar = Calendar.current

        while startDate <= endDate {
            datesArray.append(startDate)
            startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }

        return datesArray
    }

    static func getStartOfMonth(month: Int, year: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = month
        components.year = year
        return calendar.date(from: components)!
    }
}
  
