import { Role } from '@prisma/client';
export declare class AddStaffDto {
    fullName: string;
    phone: string;
    role: Role;
    password?: string;
    branchId?: string;
}
