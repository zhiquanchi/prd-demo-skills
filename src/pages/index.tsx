import { Button, Typography, Space } from 'antd';
import { SmileOutlined } from '@ant-design/icons';

export default function HomePage() {
  return (
    <div style={{ padding: 48, textAlign: 'center' }}>
      <Typography.Title>
        <SmileOutlined /> prd-demo-react
      </Typography.Title>
      <Typography.Paragraph type="secondary">
        Umi Max + antd 5 开发服务器运行正常。
      </Typography.Paragraph>
      <Space>
        <Button type="primary">Primary Button</Button>
        <Button>Default Button</Button>
      </Space>
    </div>
  );
}
