
function SDNExpressUI {

    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml]$XAML = @'
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SDN Express" ResizeMode="NoResize" Height="600" Width="800" WindowStartupLocation="CenterScreen"  >
        <Window.Resources>
            <ControlTemplate x:Key="ErrorTemplate" TargetType="{x:Type Control}">
                <DockPanel>
                    <TextBlock Foreground="Red"  TextAlignment="Center" Width="16" FontSize="18" DockPanel.Dock="Right">!</TextBlock>
                    <Border BorderThickness="1" BorderBrush="Red">
                        <ScrollViewer x:Name="PART_ContentHost"/>
                    </Border>
                </DockPanel>
            </ControlTemplate>
            <ControlTemplate x:Key="NormalTemplate" TargetType="{x:Type Control}">
                <DockPanel>
                    <TextBlock Foreground="Red" TextAlignment="Center" Width="16" FontSize="18" DockPanel.Dock="Right"></TextBlock>
                    <Border BorderThickness="1" BorderBrush="{DynamicResource {x:Static SystemColors.ControlDarkBrushKey}}">
                        <ScrollViewer x:Name="PART_ContentHost" />
                    </Border>
                </DockPanel>
            </ControlTemplate>
            <Style TargetType="{x:Type TextBox}">
                <Setter Property="OverridesDefaultStyle" Value="True" />
                <Setter Property="Template" Value="{DynamicResource ErrorTemplate}" />
            </Style>
            <Style TargetType="{x:Type PasswordBox}">
                <Setter Property="OverridesDefaultStyle" Value="True" />
                <Setter Property="Template" Value="{DynamicResource ErrorTemplate}" />
            </Style>
        </Window.Resources>
        <Grid>
            <StackPanel Name="panel0" HorizontalAlignment="Left" Width="169.149" Background="{DynamicResource {x:Static SystemColors.ControlLightBrushKey}}">
                <Rectangle Height="10" Margin="0,0,159,0" />
                <Grid>
                    <Rectangle Name="mark1" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" />
                    <Label Content="Introduction" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark2" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="VM Creation" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark3" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="Management Network" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark4" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="Provider Network" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark5" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="Network Controller" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark6" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="Software Load Balancer" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark7" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="Gateways" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark8" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="BGP" Margin="10,0,0,0"/>
                </Grid>
                <Grid>
                    <Rectangle Name="mark9" Fill="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}" Height="27.976" Margin="0,0,159,0" Visibility="Hidden"/>
                    <Label Content="Review" Margin="10,0,0,0"/>
                </Grid>
            </StackPanel>
            <StackPanel Name="panel1" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top"  Margin="169.149,0,0,0" Width="615.137">
                <TextBlock FontSize="20" Margin="10,0,0,0"><Run Text="Welcome to the SDN Express deployment wizard"/></TextBlock>
                <TextBlock Margin="10,0,10,0" TextWrapping="WrapWithOverflow">
                    <LineBreak/>
                    <Run Text="For additional information on any of these steps, click on the Docs link below. Before you can complete this wizard you must perform some prerequisite configuration steps in your network:"/><LineBreak/>
                    </TextBlock>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        Allocate a block of static IP addresses from your management subnet for each Network Controller, Mux and Gateway VM to be created.
                        </TextBlock>
                    </BulletDecorator>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        Allocate a subnet and vlan for Hyper-V Network Virtualization Provider Addresses (HNV PA).
                        </TextBlock>
                    </BulletDecorator>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        Allocate a set of subnets for Private VIPs, Public VIPs and GRE VIPs.  Do not configure these on a VLAN, instead enable them to be advertized by SDN through BGP.
                        </TextBlock>
                    </BulletDecorator>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        Configure HNV PA network's routers for BGP, with a 16-bit ASN for the router and one for SDN.  SDN should peer with the loopback address of each router.
                        </TextBlock>
                    </BulletDecorator>
                    <TextBlock Margin="10,0,0,0" TextWrapping="WrapWithOverflow">
                    <LineBreak/>
                    <Run Text="Physical switch configuration examples are "/>
                    <Hyperlink Name="uri4" NavigateUri="https://github.com/Microsoft/SDN/tree/master/SwitchConfigExamples">available on Github.</Hyperlink><LineBreak/>
                    <LineBreak/>
                    <Run Text="In addition you will need to have the following ready:"/><LineBreak/>
                    </TextBlock>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        A set of Hyper-V hosts configured with a virtual switch.
                        </TextBlock>
                    </BulletDecorator>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        A virtual hard disk containing Windows Server 2016 or 2019, Datacenter Edition.
                        </TextBlock>
                    </BulletDecorator>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        An Active Directory domain to join and credentials with Domain Join permission.
                        </TextBlock>
                    </BulletDecorator>
                    <BulletDecorator Margin="10,0,0,0">
                        <BulletDecorator.Bullet><Ellipse Height="5" Width="5" Fill="Black"/></BulletDecorator.Bullet>
                        <TextBlock TextWrapping="Wrap" HorizontalAlignment="Left" Margin="19,0,0,0">
                        Domain credentials with DNS update and host administrator priviliges.
                        </TextBlock>
                    </BulletDecorator>
                    <TextBlock Margin="10,0,0,0" TextWrapping="WrapWithOverflow">
                    <LineBreak/>
                    <Run Text="When you have completed the above you can proceed by clicking Next."/>
                    <LineBreak/>
                    <LineBreak/>
                    <Run Text="Help make SDN Express better by "/>
                    <Hyperlink Name="uri2" NavigateUri="mail:sdnfeedback@microsoft.com">providing feedback.</Hyperlink><LineBreak/>
                </TextBlock>
            </StackPanel>
            <StackPanel Name="panel2" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top"  Margin="169.149,0,0,0" Width="615.137">
                <Label Content="VM Creation" FontSize="18"  Margin="10,0"/>
                <Label Content="SDN Express is going to create a number of VMs.  This information is used for customizing those VMs." Margin="10,0"/>
                <Grid Margin="0,10"/>
                <Grid Margin="0,2">
                    <Label Content="VHD Location" Margin="10,0,0,0" HorizontalAlignment="Left" Width="122.089"/>
                    <TextBox Name="txtVHDLocation" Text="" Margin="192.739,0,119.71,0" >

                    </TextBox>
                    <Button Name="btnBrowse" Content="Browse..." Margin="0,0,10,0" HorizontalAlignment="Right" Width="104.71" Height="25.426" VerticalAlignment="Bottom"/>
                </Grid>
                <Grid Margin="0,2">
                    <Label Content="VM Path (on host)" Margin="10,0,0,0" HorizontalAlignment="Left" Width="122.089"/>
                    <TextBox Name="txtVMPath" Text="" Margin="192.739,0,119.71,0"/>
                </Grid>
                <Grid Margin="0,2">
                    <Label Content="VM Name Prefix" Margin="10,0,0,0" HorizontalAlignment="Left" Width="122.089"/>
                    <TextBox Name="txtVMNamePrefix" Text="" Margin="192.739,0,281.032,0"/>
                </Grid>
                <Grid Margin="0,10"/>
                <Grid Margin="0,2">
                    <Label Content="VM Domain" Margin="10,0,0,0" HorizontalAlignment="Left" Width="178.852"/>
                    <TextBox Name="txtVMDomain" Text="" Margin="192.739,0,119.71,0"/>
                </Grid>
                <Grid Margin="0,2">
                    <Label Content="Domain Join Username" Margin="10,0,0,0" HorizontalAlignment="Left" Width="178.852"/>
                    <TextBox Name="txtDomainJoinUsername" Text="" Margin="192.739,0,281.032,0"/>
                </Grid>
                <Grid Margin="0,2">
                    <Label Content="Domain Join Password" Margin="10,0,0,0" HorizontalAlignment="Left" Width="178.852"/>
                    <PasswordBox Name="txtDomainJoinPassword" Margin="192.739,0,281.032,0"/>
                </Grid>
                <Grid Margin="0,10"/>
                <Grid Margin="0,2">
                    <Label Content="Local Admin Password" Margin="10,0,0,0" HorizontalAlignment="Left" Width="177.739"/>
                    <PasswordBox Name="txtLocalAdminPassword" Margin="192.739,0,282.145,0"/>
                </Grid>
            </StackPanel>
            <StackPanel Name="panel3" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top" Margin="169.149,0,0,0" Width="615.137">
                <Label Content="Management Network" FontSize="18"  Margin="10,0"/>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow">
                    <Run Text="Provide information about the management network the SDN infrastructure will use to communicate.  This information is used to provide each VM with a network adapter configured for this network."/>
                </TextBlock>
                <StackPanel Margin="0,10"/>
                <Label Content="Subnet Information" Margin="10,0"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="VLAN ID" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementVLANID" Text="" Width="75"/>
                </StackPanel>
                <StackPanel  Orientation="Horizontal" Margin="0,2" >
                    <Label Content="Subnet Prefix" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementSubnetPrefix" Text="" Width="150"/>
                </StackPanel>
                <StackPanel  Orientation="Horizontal" Margin="0,2" >
                    <Label Content="Gateway" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementGateway" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="IP Address Pool" Margin="10,0"/>
                </StackPanel>
                <StackPanel  Orientation="Horizontal" Margin="0,2">
                    <Label Content="First Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementIPPoolStart" Text="" Width="150"/>
                </StackPanel>
                <StackPanel  Orientation="Horizontal" Margin="0,2">
                    <Label Content="Last Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementIPPoolEnd" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="DNS Servers" Margin="10,0"/>
                </StackPanel>
                <StackPanel  Orientation="Horizontal" Margin="0,2" >
                    <Label Content="DNS Server 1" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementDNS1" Width="150"/>
                </StackPanel>
                <StackPanel  Orientation="Horizontal" Margin="0,2" >
                    <Label Content="DNS Server 2" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementDNS2" Width="150" Template="{DynamicResource NormalTemplate}"/>
                    <Label Content="Optional" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130" FontStyle="Italic"/>
                </StackPanel>
                <StackPanel  Orientation="Horizontal" Margin="0,2" >
                    <Label Content="DNS Server 3" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtManagementDNS3" Width="150" Template="{DynamicResource NormalTemplate}"/>
                    <Label Content="Optional" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130" FontStyle="Italic"/>
                </StackPanel>
            </StackPanel>
            <StackPanel Name="panel4" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top" Margin="169.149,0,0,0" Width="615.137">
                <Label Content="Provider Network" FontSize="18"  Margin="10,0"/>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow"><Run Text="Provide information about the provider network which is used for all workload VM communication."/></TextBlock>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Subnet Information" Margin="10,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="VLAN ID" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtPAVLANID" Text="" Width="75"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Subnet Prefix" Margin="10,0,0,0" HorizontalAlignment="Left"  Width="130"/>
                    <TextBox Name="txtPASubnetPrefix" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Default Gateway" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtPAGateway" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="IP Address Pool" Margin="10,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="First IP Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtPAIPPoolStart" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Last IP Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtPAIPPoolEnd" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="MAC Address Pool" Margin="10,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="First MAC Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtMACPoolStart"  Text="" Width="150"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Last MAC Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="130"/>
                    <TextBox Name="txtMACPoolEnd" Text="" Width="150"/>
                </StackPanel>
            </StackPanel>
            <StackPanel Name="panel5" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top"  Margin="169.149,0,0,0" Width="615.137">
                <Label Content="Network Controller" FontSize="18"  Margin="10,0"/>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow">
                    <Run Text="Provide information to be used for the creation of the Network Controller and the Hyper-V hosts to be added to the controller."/>
                </TextBlock>
                <Grid Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Network Controller" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <RadioButton Name="rdoMultiNode" Content="Multi-node" HorizontalAlignment="Left" VerticalAlignment="Center" Width="91.96" IsChecked="True"/>
                    <RadioButton Name="rdoSingleode" Content="Single-node" HorizontalAlignment="Left" VerticalAlignment="Center" Width="91.96"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="REST Name (FQDN)" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtRESTName"  Text="" Width="240"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Hyper-V Hosts" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtHyperVHosts" Width="300" Height="160" TextWrapping="Wrap" AcceptsReturn="True"  VerticalScrollBarVisibility="Visible" VerticalContentAlignment="Top"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Host Credentials" Margin="10,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Username" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtHostUsername" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Password" Margin="10,0,0,0" HorizontalAlignment="Left"  Width="150"/>
                    <PasswordBox Name="txtHostPassword" Width="150"/>
                </StackPanel>
            </StackPanel>
            <StackPanel Name="panel6" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top" Margin="169.149,0,0,0" Width="615.137">
                <Label Content="Software Load Balancer" FontSize="18"  Margin="10,0"/>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow">
                    <Run Text="The Software Load Balancer is an SDN integrated L3 and L4 load balancer that is also used for network address translation (NAT).  Muxes are the routers for the virtual IP (VIP) endpoints.  Use this panel to define how many muxes you want to deploy.  All Muxes are active and traffic is spread across them automatically."/>
                </TextBlock>
                <Grid Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Load Balancer Muxes" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBlock Name="txtMuxCount" VerticalAlignment="Center" Margin="10,0" Text="{Binding ElementName=sliMuxCount, Path=Value, UpdateSourceTrigger=PropertyChanged}" />
                    <Slider Name="sliMuxCount" Width="280" Minimum="1" Maximum="8" Value="2" TickFrequency="1" VerticalAlignment="Center"  TickPlacement="BottomRight" SmallChange="1" IsSnapToTickEnabled="True"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Private VIP Subnet" FontSize="14" Margin="10,0"/>
                </StackPanel>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow">
                    <Run Text="Private VIPs are used internally by the SDN infrastructure.  This subnet must not be configured on a VLAN in the physical switch as it will be advertized by the Muxes through BGP."/>
                </TextBlock>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Subnet Prefix" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtPrivateVIPs" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Public VIP Subnet" Margin="10,0" FontSize="14" />
                </StackPanel>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow">
                    <Run Text="Public VIPs are used to directly access workloads as load balanced VIPs or for NAT.  If these need to be reached directly from the internet, then you must obtain an internet routable subnet from your Internet Service Provider (ISP).  This subnet must not be configured on a VLAN in the physical switch as it will be advertized by the Muxes through BGP."/>
                </TextBlock>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Subnet Prefix" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtPublicVIPs" Text="" Width="150"/>
                </StackPanel>
            </StackPanel>
            <StackPanel Name="panel7" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top"  Margin="169.149,0,0,0" Width="615.137">
                <Label Content="Gateways" FontSize="18"  Margin="10,0"/>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow"><Run Text="Gateways are used for routing between a virtual network and another network (local or remote).  SDN Express creates a default gateway pool that supports all connection types.  Within this pool you can select how many gateways are reserved on standby in case an active gateway fails."/></TextBlock>
                <Grid Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Gateways" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBlock Name="txtGatewayCount" VerticalAlignment="Center" Margin="10,0" Text="{Binding ElementName=sliGatewayCount, Path=Value, UpdateSourceTrigger=PropertyChanged}" />
                    <Slider Name="sliGatewayCount" Margin="35,0" Width="240" Minimum="2" Maximum="8" Value="2" TickFrequency="1" VerticalAlignment="Center"  TickPlacement="BottomRight" SmallChange="1" IsSnapToTickEnabled="True"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Gateways on standby" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBlock Name="txtRedundantCount" VerticalAlignment="Center" Margin="10,0" Text="{Binding ElementName=sliRedundantCount, Path=Value, UpdateSourceTrigger=PropertyChanged}" />
                    <Slider Name="sliRedundantCount" Width="0" Minimum="1" Maximum="7" Value="1" VerticalAlignment="Center" TickPlacement="BottomRight" SmallChange="1" IsSnapToTickEnabled="True" />
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="GRE Endpoints" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                </StackPanel>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow"><Run Text="GRE connections require an endpoint IP address that will be allocated from subnet specified below.  This subnet must not be configured on a VLAN in the physical switch as the endpoints will be advertised to the physical network through BGP."/></TextBlock>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Subnet Prefix" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtGREVIPs" Text="" Width="150"/>
                </StackPanel>
            </StackPanel>
            <StackPanel Name="panel8" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top"  Margin="169.149,0,0,0" Width="615.137">
                <Label Content="Border Gateway Protocol (BGP)" FontSize="18"  Margin="10,0"/>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow"><Run Text="BGP is used by the Software Load Balancer to advertise VIPs to the physical network.  It is also used by the gateways for advertising GRE endpoints."/></TextBlock>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="SDN ASN" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtSDNASN" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Router 1" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Router IP Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtRouterIP1" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Router ASN" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtRouterASN1" Text="" Width="150"/>
                </StackPanel>
                <StackPanel Margin="0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Router 2" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Router IP Address" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtRouterIP2" Text="" Width="150"  Template="{DynamicResource NormalTemplate}"/>
                    <Label Content="Optional" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150" FontStyle="Italic"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" Margin="0,2">
                    <Label Content="Router ASN" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150"/>
                    <TextBox Name="txtRouterASN2" Text="" Width="150"  Template="{DynamicResource NormalTemplate}"/>
                    <Label Content="Optional" Margin="10,0,0,0" HorizontalAlignment="Left" Width="150" FontStyle="Italic"/>
                </StackPanel>
            </StackPanel>
            <StackPanel Name="panel9" HorizontalAlignment="Left" Height="522.101" VerticalAlignment="Top"  Margin="169.149,0,0,0" Width="615.137">
                <Label Content="Review" FontSize="18"  Margin="10,0"/>
                <TextBlock  Margin="14,0" TextWrapping="WrapWithOverflow"><Run Text="You have entered everything required for SDN Express to configure SDN on this system.  If you would like to save this configuration, select Export.  You can re-run SDN Express later with this file using the ConfigurationDataFile parameter."/></TextBlock>
                <Grid Margin="0,10"/>
                <TextBox Name="txtReview" Text="" Margin="14,0,0,0" Height="300" Template="{DynamicResource NormalTemplate}"/>
                <Grid Margin="0,5"/>
                <Button Name="btnExport" Content="Export..." Margin="0,0,14,0" HorizontalAlignment="Right" Width="153.868" Height="34.328" />
                <TextBlock Margin="10,0,0,0" TextWrapping="WrapWithOverflow">
                    <Run Text="Help make SDN Express better by "/>
                    <Hyperlink Name="uri3" NavigateUri="mail:sdnfeedback@microsoft.com">providing feedback.</Hyperlink><LineBreak/>
                </TextBlock>

            </StackPanel>
            <TextBlock  Margin="179.149,0,0,74.328" HorizontalAlignment="Left" VerticalAlignment="Bottom">
                <Run Text="For additional help and guidance, refer to the "/>
                <Hyperlink Name="uri1" NavigateUri="https://docs.microsoft.com/en-us/windows-server/networking/sdn/plan/plan-software-defined-networking">Plan SDN topic on docs.microsoft.com.</Hyperlink>
            </TextBlock>
            <Button Name="btnBack1" Content="Back" Margin="0,0,168.868,10" HorizontalAlignment="Right" Width="153.868" Height="34.328" VerticalAlignment="Bottom"/>
            <Button Name="btnNext1" Content="Next" Margin="0,0,10,10" HorizontalAlignment="Right" Width="153.868" Height="34.328" VerticalAlignment="Bottom"/>
        </Grid>
            </Window>
'@


function ConfigDataToString {
    param (
        [object] $InputData,
        [string] $indent = ""
    )
    if ($InputData.GetType().Name.EndsWith("String")) {
        return "$indent   $InputData"
    }

    foreach ($i in $InputData.GetEnumerator()) {
        if ($i.Value.GetType().Name.EndsWith("[]")) {
            $result += ("`r`n$indent   {0}:`r`n" -f $i.key)
            foreach ($v in ($i.value)) {
                $result += "$(ConfigDataToString $v "$indent   ")`r`n"
            }
            $result += "`r`n"
        } else {
            if ($i.Value.GetType().Name.EndsWith("Object")) {
                $result += ("$indent   {0,-20}: {1}`r`n" -f $i.key, (convertto-psd1 $i.Value "$indent   "))
            }
            else {
                if (!$i.key.Contains("Password")) {
                    $result += ("$indent   {0,-20}: {1}`r`n" -f $i.key, $i.Value)
                }
            }
        } 
    }
    return $result
}   

function convertto-psd1 {
param(
    [object] $InputData,
    [string] $Indent = ""
)
    if ($InputData.GetType().Name.EndsWith("String")) {
        return "'$InputData'"
    }

    $result = "$indent@{`r`n"
    
    foreach ($i in $InputData.GetEnumerator()) {
        if ($i.Value.GetType().Name.EndsWith("Object[]")) {
            $result += "$indent   $($i.key) = @("
            $first = $true
            foreach ($v in ($i.value)) {
                if (!$first) { $result += ","}
                $result += "`r`n"
                $result += convertto-psd1 $v "$indent      "
                $first = $false
            }
            $result += "`r`n$indent   )`r`n"
        } elseif ($i.Value.GetType().Name.EndsWith("String[]")) {
            $result += "$indent   $($i.key) = @("
            $first = $true
            foreach ($v in ($i.value)) {
                if (!$first) { $result += ", "}
                $result += "'$v'"
                $first = $false
            }
            $result += " )`r`n"
        } else {
            if ($i.Value.GetType().Name.EndsWith("Object")) {
                $result += "$indent   $($i.key) = $(convertto-psd1 $i.Value "$indent   ")`r`n"
            }
            else {
                $result += "$indent   $($i.key) = '$($i.Value)'`r`n"
            }
        } 
    }
    $result += "$indent}"
    return $result
}   
        

#WARNING: this may be too slow
$ValidateFileExistsBlock = {
    if(Test-path $this.Text) { 
        $this.Template=$global:defaulttxttemplate
    } else { 
        $this.Template=$form.FindResource("ErrorTemplate") 
    } 
}


function ValidateNotBlank {
param(
    [Object] $ctl,
    [String] $message = "This field is required."
)    
    if([String]::IsNullOrEmpty($ctl.text)) {
        $ctl.Template = $form.FindResource("ErrorTemplate")
        if ([String]::IsNullOrEmpty($ctl.Tooltip)) {
            $ctl.tooltip = "Invalid value: this field is required.`r`nDetail: $message"
        } 
        return $true 
    } else { 
        $ctl.tooltip = $message
        $ctl.Template = $global:defaulttxttemplate
        return $false
    }
}

function ValidatePassword {
param(
    [Object] $ctl
)    
    if([String]::IsNullOrEmpty($ctl.password)) {
        $ctl.Template=$form.FindResource("ErrorTemplate") 
        $ctl.tooltip = "Invalid value: This field is required."
        return $true
    } else { 
        $ctl.tooltip = ""
        $ctl.Template=$global:defaulttxttemplate
        return $false 
    }
}
        

function ValidateVLAN {
param(
    [Object] $ctl
)    
    if ([Regex]::Match($ctl.text, "^\d{1,4}$").Success) {
        $value = [Int32]::Parse($ctl.text)
        if ($value -le 4096) {
            $ctl.Template=$global:defaulttxttemplate
            $ctl.tooltip = ""
            return $false
        }
        $ctl.tooltip = "Invalid value: VLAN ID must be a value between 0 and 4096."
    } else {
        $ctl.tooltip = "Invalid value: VLAN ID can't contain non-numeric characters."
    }
    $ctl.Template=$form.FindResource("ErrorTemplate") 
    return $true
}

function ValidateRegex {
    param(
        [Object] $ctl,
        [string] $Regex,
        [bool] $IsOptional = $false, 
        [string] $errormessage = "Field syntax is incorrect.",
        [string] $message = ""
    )
    if ($IsOptional -and [string]::IsNullOrEmpty($ctl.text)) {
        $ctl.ToolTip = "Invalid value: $errormessage`r`nDetail: $message"
        $ctl.Template=$global:defaulttxttemplate
        return $FALSE
    }

    if([Regex]::Match($ctl.text, $regex).Success) { 
        $ctl.Template=$global:defaulttxttemplate
        $ctl.tooltip = $message
        return $FALSE
    } else { 
        $ctl.ToolTip = "Invalid value: $errormessage`r`nDetail: $message"
        $ctl.Template=$form.FindResource("ErrorTemplate") 
        return $TRUE
    } 
}
    
function ValidateIPAddress {
    param(
        [Object] $ctl,
        [bool] $IsOptional = $false,
        [string] $message = ""
    )
    return ValidateRegex $ctl "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$" $IsOptional "IP address syntax is not correct." $message
}

function ValidateSubnetPrefix {
    param(
        [Object] $ctl,
        [bool] $IsOptional = $false,
        [string] $message = ""
    )
    return ValidateRegex $ctl "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$" $IsOptional "Subnet prefix does not match required format of <subnet>/<bits>." $message
}

function ValidateASN {
    param(
        [Object] $ctl,
        [bool] $IsOptional = $false
    )
    if ($IsOptional -and [string]::IsNullOrEmpty($ctl.text)) {
        $ctl.Template=$global:defaulttxttemplate
        $ctl.ToolTip = ""
        return $FALSE
    }

    if ([Regex]::Match($ctl.text, "^\d{1,5}$").Success) {
        $value = [Int32]::Parse($ctl.text)
        if (($value -lt 65535) -and ($value -gt 0)) {
            $ctl.ToolTip = ""
            $ctl.Template=$global:defaulttxttemplate
            return $false
        }
        $ctl.ToolTip = "ASN is outside the valid range of values.  It must be an integer number between 1 and 65534."
    } else {
        $ctl.ToolTip = "ASN contains non-numeric characters.  It must be an integer number between 1 and 65534."
    }
    $ctl.Template=$form.FindResource("ErrorTemplate") 
    return $true
}

function ValidateMACAddress {
    param(
        [Object] $ctl,
        [bool] $IsOptional = $false
    )
    if ($IsOptional -and [string]::IsNullOrEmpty($ctl.text)) {
        $ctl.Template=$global:defaulttxttemplate
        return $false
    }

    $phys = [regex]::matches($ctl.text.ToUpper().Replace(":", "").Replace("-", ""), '.{1,2}').groups.value -join "-" 

    if((![bool]($phys -as [physicaladdress])) -or ($phys.length -gt 17)) { 
        $ctl.tooltip = "Invalid mac address. Must contain 12 hexadecimal digits, can be optionally separated by : or - every two digits.  Example: 00:11:22:33:44:55"
        $ctl.Template=$form.FindResource("ErrorTemplate") 
        return $true
    } else { 
        $ctl.tooltip = ""
        $ctl.Template=$global:defaulttxttemplate
        return $false
    } 
}

function IsIPAddressInSubnet {
    param(
        [String] $IP,
        [String] $subnet
    )

    $parts = $subnet.split("/")
    if ($parts.count -ne 2) {
        return $false
    }

    $prefix = $parts[0]

    if (!($ip -as [IPAddress]) -or !($prefix -as [IPAddress])) {
        return $false
    }

    $bits = [int] $parts[1]

    $ipbytes = ($IP -as [IPaddress]).getaddressbytes()
    $prebytes = ($prefix -as [IPaddress]).getaddressbytes()

    $fullbytes = [int] ((32-$bits) / 8)
    $partbits = [int] ((32-$bits) % 8)

    for ($i=3; $i -ge (4-$fullbytes); $i--) {
        $ipbytes[$i] = 0
        $prebytes[$i] = 0
    }

    $bitmask = [byte] 0xff -shl $partbits
    $ipbytes[$i] = $ipbytes[$i] -band $bitmask
    $prebytes[$i] = $prebytes[$i] -band $bitmask

    for ($i = 0; $i -lt $ipbytes.count ; $i++) {
        if ($ipbytes[$i] -ne $prebytes[$i]) {
            return $false
        }
    }
    return $true
}

function ValidateIPAddressInSubnet {
    param(
        [Object] $ctl,
        [string] $subnet
    )

    if(!(IsIPAddressInSubnet $ctl.text $subnet)) { 
        $ctl.tooltip = "IP Address must fall within the specified subnet prefix of $subnet."
        $ctl.Template=$form.FindResource("ErrorTemplate") 
        return $true
    } else { 
        $ctl.tooltip = ""
        $ctl.Template=$global:defaulttxttemplate
        return $false
    } 
}

function ValidateIPAddressIsGreater {
    param(
        [Object] $ctl,
        [string] $lower
    )

    $greater = $ctl.text

    if (!($lower -as [IPAddress]) -or !($greater -as [IPAddress])) {
        $ctl.Template=$form.FindResource("ErrorTemplate") 
        return $true
    }

    $lbytes = ($lower -as [IPaddress]).getaddressbytes()
    $gbytes = ($greater -as [IPaddress]).getaddressbytes()

    for ($i = 0; $i -lt $lbytes.count ; $i++) {
        if ($gbytes[$i] -lt $lbytes[$i]) {
            $ctl.Template=$form.FindResource("ErrorTemplate") 
            $ctl.tooltip = "This IP address must be squentially higher than $lower."
            return $true
        }
        if ($gbytes[$i] -gt $lbytes[$i]) {
            $ctl.Template=$global:defaulttxttemplate
            $ctl.tooltip = ""
            return $false
        }
    }    

}

$ValidatePanel2 = {
    $results = @()
    $results += ValidateNotBlank $txtVHDLocation "This field must contain the full path and filename of the VHD or VHDX to use for VM creation." 
    $results += ValidateNotBlank $txtVMPath "This field must contain the path on the Hyper-V host where VM files will be placed.  This can be a UNC or CSV path as long as the host has the necessary access privileges for the share and file system."
    $results += ValidateNotBlank $txtVMNamePrefix "This field must contain a prefix which is applied to the beginning of the VM and computer name of VMs created by SDN Express."
    $results += ValidateNotBlank $txtVMDomain "This field must contain the name of the active directory domain to which the VMs will join."
    #Needs domain user validation
    $results += ValidateNotBlank $txtDomainJoinUsername "This field must contain the domain and username of a domain account that has permission to join machines to the above specified domain.  Example: CONTOSO\alyoung"  
    $results += ValidatePassword $txtDomainJoinPassword 
    $results += ValidatePassword $txtLocalAdminPassword 

    foreach ($result in $results) {
        if ($result) {
            $btnNext1.IsEnabled = $false
            return
        }
    }
    $btnNext1.IsEnabled = $true
}

$ValidatePanel3 = {
    $results = @()
    $results += ValidateVLAN $txtManagementVLANID 
    $results += ValidateSubnetPrefix $txtManagementSubnetPrefix $false "Enter the subnet prefix of the management subnet.  Example: 192.168.0.0/24"
    $results += ValidateIPAddress $txtManagementGateway $false "Enter the IP address of managemetn subnet's gateway."
    $results += ValidateIPAddress $txtManagementIPPoolStart $false "Enter the first IP address to assign to the management interface of the SDN infrastructure VMs created by SDN Express."
    $results += ValidateIPAddress $txtManagementIPPoolEnd $false "Enter the last IP address to assign to the management interface of the SDN infrastructure VMs created by SDN Express.  There must be enough addresses in this pool to assign one address to each VM created."
    $results += ValidateIPAddress $txtManagementDNS1  $false "Enter a DNS server to assign to the SDN infrastructure VMs created by SDN express."
    $results += ValidateIPAddress $txtManagementDNS2 $true "Optionally enter additional DNS servers to assign to the SDN infrastructure VMs created by SDN Express."
    $results += ValidateIPAddress $txtManagementDNS3 $true  "Optionally enter additional DNS servers to assign to the SDN infrastructure VMs created by SDN Express."

    $results += ValidateIPAddressInSubnet $txtManagementGateway $txtManagementSubnetPrefix.Text
    $results += ValidateIPAddressInSubnet $txtManagementIPPoolStart $txtManagementSubnetPrefix.Text
    $results += ValidateIPAddressInSubnet $txtManagementIPPoolEnd $txtManagementSubnetPrefix.Text
    $results += ValidateIPAddressIsGreater $txtManagementIPPoolEnd $txtManagementIPPoolStart.Text

    foreach ($result in $results) {
        if ($result) {
            $btnNext1.IsEnabled = $false
            return
        }
    }
    $btnNext1.IsEnabled = $true
}

$ValidatePanel4 = {
    $results = @()
    $results += ValidateVLAN $txtPAVLANID 
    $results += ValidateSubnetPrefix $txtPASubnetPrefix 
    $results += ValidateIPAddress $txtPAGateway 
    $results += ValidateIPAddress $txtPAIPPoolStart 
    $results += ValidateIPAddress $txtPAIPPoolEnd 
    $results += ValidateMACAddress $txtMacPoolStart 
    $results += ValidateMACAddress $txtMacPoolEnd
    
    foreach ($result in $results) {
        if ($result) {
            $btnNext1.IsEnabled = $false
            return
        }
    }
    $btnNext1.IsEnabled = $true
}

$ValidatePanel5 = {
    $results = @()
    $results += ValidateNotBlank $txtRESTName "This field must contain the fully qualified domain name to be assigned to the REST interface of the network controller."
    $results += ValidateNotBlank $txtHyperVHosts "This field must contain a list of Hyper-V hosts to be added to the network controller.  They must be separated by newlines, commas or semicolons."
    $results += ValidateNotBlank $txtHostUsername "This domain and username is used by the network controller to access the Hyper-V hosts and SDN gateways running on the hsots.  Example: CONTOSO\AlYoung"
    $results += ValidatePassword $txtHostPassword 

    foreach ($result in $results) {
        if ($result) {
            $btnNext1.IsEnabled = $false
            return
        }
    }
    $btnNext1.IsEnabled = $true
}

$ValidatePanel6 = {
    $results = @()
    $results += ValidateSubnetPrefix $txtPrivateVIPs 
    $results += ValidateSubnetPrefix $txtPublicVIPs 

    foreach ($result in $results) {
        if ($result) {
            $btnNext1.IsEnabled = $false
            return
        }
    }
    $btnNext1.IsEnabled = $true
}
$ValidatePanel7 = {
    $results = @()
    $results += ValidateSubnetPrefix $txtGREVIPs 
    
    foreach ($result in $results) {
        if ($result) {
            $btnNext1.IsEnabled = $false
            return
        }
    }
    $btnNext1.IsEnabled = $true
}

$ValidatePanel8 = {
    $results = @()
    $results += ValidateASN $txtSDNASN 
    $results += ValidateIPAddress $txtRouterIP1 
    $results += ValidateASN $txtRouterASN1 
    $results += ValidateIPAddress $txtRouterIP2 $true
    $results += ValidateASN $txtRouterASN2 $true

    foreach ($result in $results) {
        if ($result) {
            $btnNext1.IsEnabled = $false
            return
        }
    }
    $btnNext1.IsEnabled = $true
}

    function AddTxtValidation {
    param(
    $objtxt,
    $block
    )
        $objtxt.Add_TextChanged($block)
    }


function GetNextIP {
    param (
        $Ip
        )
        if (!($IP -as [IPAddress]))
        {
            return ""
        }

        $mb = ($IP -as [IPaddress]).getaddressbytes()

        for ($c = $mb.count; $c -gt 0; $c--) {
            if ($mb[$c-1] -eq 0xff) {
                $mb[$c-1] = 0
            } else {
                $mb[$c-1]++
                return ($mb -as [ipaddress]).ToString()
            }
        }
    }

function GetNextMAC {
param (
    $Mac
    )
    $mac = [regex]::matches($mac.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"

    if (!($mac -as [physicaladdress])) {
        return ""
    }

    $mb = ($mac -as [physicaladdress]).getaddressbytes()

    for ($c = $mb.count; $c -gt 0; $c--) {
        if ($mb[$c-1] -eq 0xff) {
            $mb[$c-1] = 0
        } else {
            $mb[$c-1]++
            $newmac = ($mb -as [physicaladdress]).ToString()
            return [regex]::matches($newmac.ToUpper().Replace(":", "").Replace("-", ""), '..').groups.value -join "-"
        }
    }
}
        
    function GenerateConfigData {
        $ConfigData = [ordered] @{}
    
        $Path = $txtVHDLocation.Text
        if (![string]::IsNullOrEmpty($path)) {
            $PathParts = $path.Split("\")
            
            $ConfigData.ScriptVersion     = "2.0"

            $ConfigData.VHDPath           = $Path.substring(0, $Path.length-$PathParts[$PathParts.Count-1].length-1)
            $ConfigData.VHDFile           = $PathParts[$PathParts.Count-1]
        }

        $ConfigData.VMLocation        = $txtVMPath.Text
        $ConfigData.JoinDomain        = $txtVMDomain.text
    
        $ConfigData.ManagementVLANID  = $txtManagementVLANID.text
        $ConfigData.ManagementSubnet  = $txtManagementSubnetPrefix.text
        $ConfigData.ManagementGateway = $txtManagementGateway.text
        $ConfigData.ManagementDNS     = @()
        $ConfigData.ManagementDNS    += $txtManagementDNS1.text
        if (![String]::IsNullOrEmpty($txtManagementDNS2.text)) { $ConfigData.ManagementDNS    += $txtManagementDNS2.text }
        if (![String]::IsNullOrEmpty($txtManagementDNS3.text)) { $ConfigData.ManagementDNS    += $txtManagementDNS3.text }
    
        $ConfigData.DomainJoinUsername   = $txtDomainJoinUsername.text
        $ConfigData.DomainJoinSecurePassword   = $txtDomainJoinPassword.Password | ConvertTo-SecureString -AsPlainText -Force | convertfrom-securestring
    
        $ConfigData.LocalAdminSecurePassword   = $txtLocalAdminPassword.Password | ConvertTo-SecureString -AsPlainText -Force | convertfrom-securestring
    
        $ConfigData.LocalAdminDomainUser = $txtHostUserName.text
    
        $ConfigData.RestName = $txtRESTName.Text
    
        $hosttxt = $txtHyperVHosts.text
        $hosttxt = $hosttxt.Replace("`r", "").Replace(" ", "")
        $hosts = $hosttxt.Split("`n,;")
        $ConfigData.HyperVHosts = $hosts
    
    
        $nexthost = 0
        $nextIP = $txtManagementIPPoolStart.Text
        $nextPA = $txtPAIPPoolStart.Text
        $nextMAC = $txtMacPoolStart.Text
    
        $ConfigData.NCs = @()
        $ConfigData.NCs += [ordered] @{ComputerName="$($txtVMNamePrefix.Text)NC01"; HostName=$hosts[$nexthost]; ManagementIP=$nextIP; MACAddress=$nextMac}
    
        $nextip = GetNextIP $nextip
        $nextmac = GetNextMac $nextmac
        $nexthost = ($nexthost + 1) % $hosts.count
    
        if ($rdoMultiNode.IsChecked) {
    
            $ConfigData.NCs += [ordered] @{ComputerName="$($txtVMNamePrefix.Text)NC02"; HostName=$hosts[$nexthost]; ManagementIP=$nextIP; MACAddress=$nextMac}
            $nextip = GetNextIP $nextip
            $nextmac = GetNextMac $nextmac
            $nexthost = ($nexthost + 1) % $hosts.count
    
            $ConfigData.NCs += [ordered] @{ComputerName="$($txtVMNamePrefix.Text)NC03"; HostName=$hosts[$nexthost]; ManagementIP=$nextIP; MACAddress=$nextMac}
            $nextip = GetNextIP $nextip
            $nextmac = GetNextMac $nextmac
            $nexthost = ($nexthost + 1) % $hosts.count
        }
    
        $ConfigData.Muxes = @()
        for ($c = 1; $c -le $sliMuxCount.Value; $c++) {
    
            $mgmtmac = $nextmac
            $nextmac = getnextmac $nextmac
            $pamac = $nextmac
            $nextmac = getnextmac $nextmac
    
            $ConfigData.Muxes += [ordered] @{ComputerName="$($txtVMNamePrefix.Text)Mux{0:00}" -f $c; HostName=$hosts[$nexthost]; ManagementIP=$nextip; MACAddress=$mgmtmac; PAIPAddress=$nextpa; PAMACAddress=$pamac}
    
            $nexthost = ($nexthost + 1) % $hosts.count
            $nextip = getnextip $nextip
            $nextpa = getnextip $nextpa
    
        }
    
        $papoolstart = $nextpa
    
        $ConfigData.Gateways = @()
        for ($c = 1; $c -le $sliGatewayCount.Value; $c++) {
            $mgmtmac = $nextmac
            $nextmac = getnextmac $nextmac
            $femac = $nextmac
            $nextmac = getnextmac $nextmac
            $bemac = $nextmac
            $nextmac = getnextmac $nextmac
    
            $ConfigData.Gateways += [ordered] @{ComputerName="$($txtVMNamePrefix.Text)GW{0:00}" -f $c; HostName=$hosts[$nexthost]; ManagementIP=$nextip; MACAddress=$mgmtmac; FrontEndIp=$nextpa; FrontEndMac=$femac; BackEndMac=$bemac}
    
            $nexthost = ($nexthost + 1) % $hosts.count
            $nextip = getnextip $nextip
            $nextpa = getnextip $nextpa
    
        }
    
        $ConfigData.NCUsername   = $txtHostUsername.Text
        $ConfigData.NCSecurePassword   = $txtHostPassword.Password | ConvertTo-SecureString -AsPlainText -Force | convertfrom-securestring
    
        $ConfigData.PAVLANID         = $txtPAVLANID.text
        $ConfigData.PASubnet         = $txtPASubnetPrefix.text
        $ConfigData.PAGateway        = $txtPAGateway.text
        $ConfigData.PAPoolStart      = $papoolstart
        $ConfigData.PAPoolEnd        = $txtPAIPPoolEnd.Text
    
        $ConfigData.SDNMacPoolStart      = $nextMAC
        $ConfigData.SDNMacPoolEnd        = $txtMacPoolEnd.Text
    
        $ConfigData.SDNASN =           $txtSDNASN.text
        $ConfigData.Routers = @(
            [ordered] @{ RouterASN=$txtRouterASN1.text; RouterIPAddress=$txtRouterIP1.text}
        )
        if (![String]::IsNullOrEmpty($txtRouterIP2.text)) { 
            $ConfigData.Routers +=  [ordered] @{ RouterASN=$txtRouterASN2.text; RouterIPAddress=$txtRouterIP2.text}
        }
    
        $ConfigData.PrivateVIPSubnet = $txtPrivateVIPs.text
        $ConfigData.PublicVIPSubnet  = $txtPublicVIPs.text
    
        $ConfigData.PoolName         = "DefaultAll"
        $ConfigData.GRESubnet        = $txtGREVIPs.text
    
    
        $ConfigData.Capacity         = 10000
    
    
        return $ConfigData
    }

    
    function SetPanel
    {
    param(
    $PanelIndex
    )
        if ($panelIndex -eq 1) { $mark1.Visibility = "Visible"; $panel1.Visibility = "Visible"; } else { $mark1.Visibility = "Hidden"; $panel1.Visibility = "Hidden" }
        if ($panelIndex -eq 2) { $mark2.Visibility = "Visible"; $panel2.Visibility = "Visible";  invoke-command $ValidatePanel2 } else { $mark2.Visibility = "Hidden"; $panel2.Visibility = "Hidden" }
        if ($panelIndex -eq 3) { $mark3.Visibility = "Visible"; $panel3.Visibility = "Visible";  invoke-command $ValidatePanel3 } else { $mark3.Visibility = "Hidden"; $panel3.Visibility = "Hidden" }
        if ($panelIndex -eq 4) { $mark4.Visibility = "Visible"; $panel4.Visibility = "Visible";  invoke-command $ValidatePanel4 } else { $mark4.Visibility = "Hidden"; $panel4.Visibility = "Hidden" }
        if ($panelIndex -eq 5) { $mark5.Visibility = "Visible"; $panel5.Visibility = "Visible";  invoke-command $ValidatePanel5 } else { $mark5.Visibility = "Hidden"; $panel5.Visibility = "Hidden" }
        if ($panelIndex -eq 6) { $mark6.Visibility = "Visible"; $panel6.Visibility = "Visible";  invoke-command $ValidatePanel6 } else { $mark6.Visibility = "Hidden"; $panel6.Visibility = "Hidden" }
        if ($panelIndex -eq 7) { $mark7.Visibility = "Visible"; $panel7.Visibility = "Visible";  invoke-command $ValidatePanel7 } else { $mark7.Visibility = "Hidden"; $panel7.Visibility = "Hidden" }
        if ($panelIndex -eq 8) { $mark8.Visibility = "Visible"; $panel8.Visibility = "Visible" } else { $mark8.Visibility = "Hidden"; $panel8.Visibility = "Hidden" }
        if ($panelIndex -eq 9) { 
            $mark9.Visibility = "Visible"; 
            $panel9.Visibility = "Visible"; 
            $btnNext1.Content = "Deploy"
            $txtReview.Text =  ConfigDataToString (GenerateConfigData)
        } else { 
            $mark9.Visibility = "Hidden"; 
            $panel9.Visibility = "Hidden"; 
            $btnNext1.Content = "Next"
        }
        if ($panelIndex -eq 10) { $global:Deploy = $true; $form.Close() }
    }


    #Read XAML
    $reader=(New-Object System.Xml.XmlNodeReader $xaml) 
    try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
    catch{Write-Host "Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered."; exit}

    $xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)}

    $global:PanelIndex = 1
    $global:Deploy = $false
    $global:defaulttxttemplate = $form.FindResource("NormalTemplate") 

    $btnBack1.IsEnabled = $false

    $uri1.Add_Click({ Start-Process -FilePath $this.NavigateUri})
    $uri2.Add_Click({ Start-Process -FilePath $this.NavigateUri})
    $uri3.Add_Click({ Start-Process -FilePath $this.NavigateUri})
    $uri4.Add_Click({ Start-Process -FilePath $this.NavigateUri})
    
    $btnBack1.Add_Click({$global:PanelIndex=$global:panelIndex - 1; SetPanel $global:panelIndex; if ($global:panelIndex -eq 1) { $btnBack1.IsEnabled = $false }})
    $btnNext1.Add_Click({$global:PanelIndex=$global:panelIndex + 1; SetPanel $global:panelIndex; if ($global:panelIndex -gt 1) { $btnBack1.IsEnabled = $true  }})
    $btnBrowse.Add_Click({
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.initialDirectory = $txtVHDLocation.text
        $ofd.filter = "Virtual Hard Disks (*.vhdx; *.vhd)|*.vhdx;*.vhd"
        $ofd.ShowDialog() | Out-Null
        $txtVHDLocation.text = $ofd.Filename
    })
    $btnExport.Add_Click({
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

        $ofd = New-Object System.Windows.Forms.SaveFileDialog
        $ofd.filter = "Powershell (*.psd1)|*.psd1"
        $result = $ofd.ShowDialog()

        if ($result)
        {
            $fn = $ofd.filename
            $ConfigData = GenerateConfigData
            
            "" | out-file $fn 
            Convertto-psd1 $ConfigData | out-file $fn -append

            $Result = $null
        }
    })


    # Panel 2 Validation
    AddTxtValidation $txtVHDLocation $ValidatePanel2
    AddTxtValidation $txtVMPath $ValidatePanel2
    AddTxtValidation $txtVMNamePrefix $ValidatePanel2
    AddTxtValidation $txtVMDomain $ValidatePanel2
    AddTxtValidation $txtDomainJoinUsername $ValidatePanel2  #Needs domain user validation
    $txtDomainJoinPassword.Add_PasswordChanged($ValidatePanel2)
    $txtLocalAdminPassword.Add_PasswordChanged($ValidatePanel2)

    # Panel 3 Validation
    AddTxtValidation $txtManagementVLANID $ValidatePanel3
    AddTxtValidation $txtManagementSubnetPrefix $ValidatePanel3 
    AddTxtValidation $txtManagementGateway $ValidatePanel3
    AddTxtValidation $txtManagementIPPoolStart $ValidatePanel3
    AddTxtValidation $txtManagementIPPoolEnd $ValidatePanel3
    AddTxtValidation $txtManagementDNS1 $ValidatePanel3
    AddTxtValidation $txtManagementDNS2 $ValidatePanel3 
    AddTxtValidation $txtManagementDNS3 $ValidatePanel3 

    # Panel 4 Validation
    AddTxtValidation $txtPAVLANID $ValidatePanel4
    AddTxtValidation $txtPASubnetPrefix $ValidatePanel4
    AddTxtValidation $txtPAGateway $ValidatePanel4
    AddTxtValidation $txtPAIPPoolStart $ValidatePanel4
    AddTxtValidation $txtPAIPPoolEnd $ValidatePanel4

    $txtMacPoolStart.Text = "00:1D:D8:B7:1C:00"
    $txtMacPoolEnd.Text = "00:1D:D8:B7:1F:FF"
    
    AddTxtValidation $txtMacPoolStart $ValidatePanel4
    AddTxtValidation $txtMacPoolEnd $ValidatePanel4

    # Panel 5 Validation
    AddTxtValidation $txtRESTName $ValidatePanel5
    AddTxtValidation $txtHyperVHosts $ValidatePanel5  # Needs multiline host validation
    AddTxtValidation $txtHostUsername $ValidatePanel5 # Needs domain user validation
    $txtHostPassword.Add_PasswordChanged($ValidatePanel5)

    # Panel 6 Validation
    AddTxtValidation $txtPrivateVIPs $ValidatePanel6
    AddTxtValidation $txtPublicVIPs $ValidatePanel6

    # Panel 7 Validation
    AddTxtValidation $txtGREVIPs $ValidatePanel7 

    # Panel 8 Validation
    AddTxtValidation $txtSDNASN $ValidatePanel8
    AddTxtValidation $txtRouterIP1 $ValidatePanel8
    AddTxtValidation $txtRouterASN1 $ValidatePanel8
    AddTxtValidation $txtRouterIP2 $ValidatePanel8
    AddTxtValidation $txtRouterASN2 $ValidatePanel8

    SetPanel $PanelIndex

    $sliGatewayCount.Add_ValueChanged({
        $newmax = $sliGatewayCount.Value-1
        if ($sliRedundantCount.Value -gt $newmax) {
            $sliRedundantCount.Value = $newmax
        }
        $sliRedundantCount.Maximum = $newmax
        $sliRedundantCount.Width = ($newmax-1) * 40

    })

    $Form.ShowDialog() | out-null

    if ($global:deploy) {
        return GenerateConfigData
    }
}