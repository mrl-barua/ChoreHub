export declare function createNotification(userId: string, familyId: string, type: string, title: string, body: string, data?: string): Promise<{
    data: string | null;
    id: string;
    createdAt: Date;
    userId: string;
    familyId: string;
    title: string;
    type: string;
    body: string;
    read: boolean;
}>;
