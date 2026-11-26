db.createView(
    "vw_unread_notification_count",
    "notification_log",
    [
        {
            $match: {
                isRead: false
            }
        },
        {
            $group: {
                _id: "$subscriberId",
                unreadCount: { $sum: 1 }
            }
        },
        {
            $project: {
                _id: 0,
                subscriberId: "$_id",
                unreadCount: 1
            }
        },
        {
            $sort: {
                subscriberId: 1
            }
        }
    ]
);

// Display unread notification counts
db.vw_unread_notification_count.find();
