import type { Meta, StoryObj } from '@storybook/react-vite';
import { UsersList } from './UsersList';

const meta: Meta<typeof UsersList> = {
    title: 'Components/UsersList',
    component: UsersList,
};

export default meta;

type Story = StoryObj<typeof UsersList>;

export const Default: Story = {
    args: {
        total: 3,
        users: [
            {
                id: 1,
                name: 'Ada Lovelace',
                email: 'ada@example.com',
                createdAt: '2026-04-12T00:00:00.000Z',
            },
            {
                id: 2,
                name: 'Alan Turing',
                email: 'alan@example.com',
                createdAt: '2026-04-12T00:00:00.000Z',
            },
            {
                id: 3,
                name: 'Grace Hopper',
                email: 'grace@example.com',
                createdAt: '2026-04-12T00:00:00.000Z',
            },
        ],
    },
};

export const Empty: Story = {
    args: {
        total: 0,
        users: [],
    },
};

export const SingleUser: Story = {
    args: {
        total: 1,
        users: [
            {
                id: 1,
                name: 'Ada Lovelace',
                email: 'ada@example.com',
                createdAt: '2026-04-12T00:00:00.000Z',
            },
        ],
    },
};
